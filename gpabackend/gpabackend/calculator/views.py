from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from .models import Semester, Subject, Grade, GradeDetail, CGPAPrediction
from accounts.models import CustomUser
from .courses import CREDITS
from .minor import MINOR, HONOR  # Import the credits from minor.py
from django.db.models import Max, Min, Count, Q  # Add this import
from django.http import HttpResponse
from subprocess import run, PIPE  # To execute Dart script
import json
from django.http import JsonResponse
from .cgpa_predictor import cgpa_predictor

cgpa=0
# Grade values mapping
GRADE_VALUES = {
    'S': 10, 'A+': 9, 'A': 8.5, 'B+': 8, 'B': 7.5, 'C+': 7, 'C': 6.5, 'D+': 6, 'P': 5.5, 'F': 0
}

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_subjects(request):
    """
    Returns the list of subjects and credits for each semester based on the user's degree.
    """
    user = request.user
    degree = user.degree
    print("User degree:", degree)  # Log the user's degree
    if degree not in CREDITS:
        response_data = {'error': 'Invalid degree'}
        print("Response data:", response_data)  # Log the response
        return Response(response_data, status=status.HTTP_400_BAD_REQUEST)
    
    response_data = CREDITS[degree]
    print("Response data:", response_data)  # Log the response
    return Response(response_data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_data(request):
    try:
        user = request.user
        semesters = Semester.objects.filter(user=user).prefetch_related('subjects__grade')

        semester_data = []
        for semester in semesters:
            semester_info = {
                'semester': semester.semester,
                'gpa': semester.gpa,
                'minor_gpa': semester.minor_gpa,
                'subjects': []
            }

            for subject in semester.subjects.all():
                try:
                    grade = subject.grade.grade
                except Grade.DoesNotExist:
                    grade = None

                semester_info['subjects'].append({
                    'name': subject.name,
                    'credits': subject.credits,
                    'grade': subject.grade.grade if subject.grade else 'N/A'
                })

            semester_data.append(semester_info)

        all_gpas = [s.gpa for s in semesters if s.gpa is not None]
        cgpa = sum(all_gpas) / len(all_gpas) if len(all_gpas) > 0 else 0.0

        response_data = {
            'user': {
                'ktuid': user.KTUID,  # Ensure KTUID is included
                'degree': user.degree,
                'semester': user.semester,
            },
            'semesters': semester_data,
            'cgpa': round(cgpa, 2)
        }

        print("Response data:", response_data)  # Log the response
        return Response(response_data, status=status.HTTP_200_OK)

    except Exception as e:
        print("Error in get_user_data:", e)
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def calculate_gpa(request):
    try:
        print("Received request data:", request.data)  # Log the received request data
        data = request.data
        user = request.user
        semester = data.get('semester')
        grades = data.get('grades', {})

        # Validate semester
        if not semester or not isinstance(semester, str):
            print("Invalid semester:", semester)  # Log invalid semester
            return Response(
                {'error': 'Invalid semester'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validate grades
        if not isinstance(grades, dict):
            print("Invalid grades format:", grades)  # Log invalid grades
            return Response(
                {'error': 'Invalid grades format'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check if the semester is within the user's current semester
        user_current_semester = user.semester
        try:
            semester_number = int(semester.split('_')[-1])
            user_current_semester_number = int(user_current_semester.split('_')[-1])
        except (IndexError, ValueError):
            return Response(
                {'error': 'Invalid semester format'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if semester_number > user_current_semester_number:
            return Response(
                {'error': 'You can only calculate GPA up to your current semester.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create or update semester
        semester_obj, created = Semester.objects.get_or_create(
            user=user,
            semester=semester
        )

        # Reset total_credits, total_points, and earn_credits
        semester_obj.total_credits = 0
        semester_obj.total_points = 0
        semester_obj.earn_credits = 0

        for subject_name, grade in grades.items():
            # Validate subject and credits
            credits = None
            for slot, courses in CREDITS[user.degree].get(semester, {}).items():
                if subject_name.strip() in courses:
                    credits = courses[subject_name.strip()]
                    break

            if credits is None:
                print(f"Credits not found for subject '{subject_name}' in {semester}")  # Log missing credits
                return Response(
                    {'error': f'Credits not found for subject "{subject_name}" in {semester}'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Validate grade
            if grade not in GRADE_VALUES:
                print(f"Invalid grade '{grade}' for subject '{subject_name}'")  # Log invalid grade
                return Response(
                    {'error': f'Invalid grade "{grade}" for subject "{subject_name}"'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            subject, _ = Subject.objects.get_or_create(
                semester=semester_obj,
                name=subject_name.strip(),
                defaults={'credits': credits}
            )

            subject.credits = credits
            subject.save()

            Grade.objects.update_or_create(
                subject=subject,
                defaults={'grade': grade}
            )

            if grade in GRADE_VALUES:
                print("Grade:", GRADE_VALUES[grade]) 
                
                semester_obj.total_credits += subject.credits
                gcredit = GRADE_VALUES[grade] * subject.credits
                semester_obj.total_points += gcredit
                
                print(GRADE_VALUES[grade] ,"*", subject.credits,"=",gcredit)  # Log grade and credits
                if grade != 'F':
                    semester_obj.earn_credits += subject.credits
                    semester_obj.complete_courses += 1  # Increment complete courses count
        print("Total credits:", semester_obj.total_credits)  # Log total credits
        print("Total points:", semester_obj.total_points)  # Log total points   
        print("Earned credits:", semester_obj.earn_credits)  # Log earned credits
        if semester_obj.total_credits == 0:
            return Response(
                {'error': 'No valid grades provided'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Save GPA for the semester
        gpa = semester_obj.total_points / semester_obj.total_credits
        semester_obj.gpa = gpa
        semester_obj.save()

        # Calculate and update CGPA for the user
        all_semesters = Semester.objects.filter(user=user)
        try:
            cgpa = sum(s.gpa for s in all_semesters if s.gpa is not None) / len(all_semesters)
        except TypeError as e:
            print("TypeError in CGPA calculation:", e)
            return Response(
                {'error': f'TypeError in CGPA calculation: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user.cgpa = cgpa  # Update the user's CGPA
        user.save()
        print("CGPA:", user.cgpa)  # Log CGPA
        print("GPA and CGPA calculated successfully")  # Log successful calculation
        return Response({
            'semester_gpa': round(gpa, 2),
            'cgpa': round(cgpa, 2)
        }, status=status.HTTP_200_OK)

    except Exception as e:
        print("An error occurred:", e)  # Print the error
        return Response(
            {'error': f'An unexpected error occurred: {str(e)}'},
            status=status.HTTP_400_BAD_REQUEST
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def calculate_grade(request):
    try:
        print("Request body:", request.data)  # Log request body
        marks = request.data.get('marks')
        subject_name = request.data.get('subject')  # Get subject name from request
        semester_name = request.data.get('semester')  # Get semester name from request

        if marks is None or not subject_name or not semester_name:
            response_data = {'error': 'Marks, subject, and semester are required'}
            print("Response body:", response_data)  # Log response body
            return Response(response_data, status=status.HTTP_400_BAD_REQUEST)

        try:
            marks = float(marks)
        except ValueError:
            response_data = {'error': 'Invalid marks format'}
            print("Response body:", response_data)  # Log response body
            return Response(response_data, status=status.HTTP_400_BAD_REQUEST)

        if marks < 0 or marks > 150:
            response_data = {'error': 'Marks should be between 0 and 150'}
            print("Response body:", response_data)  # Log response body
            return Response(response_data, status=status.HTTP_400_BAD_REQUEST)

        # Determine grade based on marks
        grade = None
        if marks >= 135:
            grade = 'S'
        elif marks >= 127.5:
            grade = 'A+'
        elif marks >= 120:
            grade = 'A'
        elif marks >= 112.5:
            grade = 'B+'
        elif marks >= 105:
            grade = 'B'
        elif marks >= 97.5:
            grade = 'C+'
        elif marks >= 90:
            grade = 'C'
        elif marks >= 82.5:
            grade = 'D+'
        elif marks >= 75:
            grade = 'P'
        else:
            grade = 'F'

        # Save the grade in the new GradeDetail model
        user = request.user
        semester, _ = Semester.objects.get_or_create(user=user, semester=semester_name)

        # Determine credits for the subject from CREDITS mapping
        credits = None
        try:
            degree_credits = CREDITS.get(user.degree, {})
            semester_slots = degree_credits.get(semester_name, {})
            for slot, courses in semester_slots.items():
                # courses is expected to be a dict mapping subject names to credit values
                if subject_name.strip() in courses:
                    credits = courses[subject_name.strip()]
                    break
        except Exception as e:
            print(f"Error while looking up credits: {e}")

        if credits is None:
            # If credits cannot be determined, return an informative error
            response_data = {'error': f'Credits not found for subject "{subject_name}" in {semester_name}'}
            print("Response body:", response_data)  # Log response body
            return Response(response_data, status=status.HTTP_400_BAD_REQUEST)

        # Ensure subject is created with credits (avoid NOT NULL constraint failures)
        subject, _ = Subject.objects.get_or_create(
            semester=semester,
            name=subject_name.strip(),
            defaults={'credits': credits}
        )
        # Update credits to the resolved value in case it changed or was missing
        subject.credits = credits
        subject.save()

        # Create or update a GradeDetail object
        GradeDetail.objects.update_or_create(
            subject=subject,
            defaults={'marks': marks, 'grade': grade}
        )

        # Also update the simple Grade model so saved grades appear in get_user_data
        try:
            Grade.objects.update_or_create(
                subject=subject,
                defaults={'grade': grade}
            )
        except Exception as e:
            print(f"Warning: failed to update Grade model: {e}")

        response_data = {
            'subject': subject_name,
            'semester': semester_name,
            'marks': marks,
            'grade': grade
        }
        print("Response body:", response_data)  # Log response body
        return Response(response_data, status=status.HTTP_200_OK)

    except Exception as e:
        response_data = {'error': str(e)}
        print("Response body:", response_data)  # Log response body
        return Response(response_data, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def calculate_minor(request):
    try:
        print("Request received for minor calculation")  # Log request received
        print("Request body:", request.body)  # Log raw request body
        data = request.data
        print("Received payload:", data)  # Print the received payload

        user = request.user
        semester = data.get('semester')
        minor_grades = data.get('minor_grades', {})
        Bucket = data.get('Bucket', 'Bucket 1')  # Define and get the selected bucket
        Type = data.get('Type', 'Minor')  # Define and get the selected type (Minor or Honor)
        print("THIS ISSSSS", minor_grades)  # Ensure this line is executed

        # Validate semester
        if not semester or not isinstance(semester, str):
            return Response(
                {'error': 'Invalid semester'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check if the semester is within the user's current semester
        user_current_semester = user.semester  # Use the semester field from CustomUser model
        try:
            semester_number = int(semester.split('_')[-1])
            user_current_semester_number = int(user_current_semester.split('_')[-1])
        except (IndexError, ValueError):
            return Response(
                {'error': 'Invalid semester format'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if semester_number > user_current_semester_number:
            return Response(
                {'error': 'You can only calculate GPA up to your current semester.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get the existing semester object
        semester_obj = Semester.objects.get(user=user, semester=semester)

        # Initialize total_credits and total_points if not already set
        if semester_obj.total_credits is None:
            semester_obj.total_credits = 0
        if semester_obj.total_points is None:
            semester_obj.total_points = 0
        print("semester_obj.total_credits:", semester_obj.total_credits)  # Log total_credits
        print("semester_obj.total_points:", semester_obj.total_points)  # Log total_points

        # Select the correct dictionary based on the type
        selected_dict = MINOR if Type == 'Minor' else HONOR

        for subject_name, grade in minor_grades.items():
            # Use the original subject name directly
            credits = selected_dict[user.degree].get(Bucket, {}).get(semester, {}).get(subject_name.strip())  # Correct reference to selected_dict
           
            if credits is None:
                print(f'Credits not found for subject "{subject_name}" in {semester}')  # Log missing credits
                return Response(
                    {'error': f'Credits not found for subject "{subject_name}" in {semester}'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Save or update the subject and grade
            subject, _ = Subject.objects.get_or_create(
                semester=semester_obj,
                name=subject_name.strip(),
                defaults={'credits': credits}
            )
            subject.credits = credits
            subject.save()

            Grade.objects.update_or_create(
                subject=subject,
                defaults={'grade': grade}
            )

            # Calculate additional SGPA
            if grade in GRADE_VALUES:
                semester_obj.total_credits += credits
                semester_obj.total_points += GRADE_VALUES[grade] * credits

        if semester_obj.total_credits == 0:
            return Response(
                {'error': 'No valid grades provided'},
                status=status.HTTP_400_BAD_REQUEST
            )
        print("semester_obj.total_credits:", semester_obj.total_credits)  # Log total_credits
        print("semester_obj.total_points:", semester_obj.total_points)  # Log total_points
        # Save updated SGPA for the semester
        acsgpa = semester_obj.total_points / semester_obj.total_credits
        semester_obj.minor_gpa = acsgpa  # Save the minor GPA in the database
        semester_obj.save()  # Persist the changes to the database
        print("SGPA:", semester_obj.gpa, "Minor GPA:", semester_obj.minor_gpa)  # Log successful SGPA calculation

        all_semesters = Semester.objects.filter(user=user)
        try:
            minor_cgpa = sum(s.gpa for s in all_semesters if s.gpa is not None) / len(all_semesters)
        except TypeError as e:
            print("TypeError in CGPA calculation:", e)
            return Response(
                {'error': f'TypeError in CGPA calculation: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Include updated grades in the response
        updated_grades = {
            subject.name: subject.grade.grade if subject.grade else None
            for subject in semester_obj.subjects.all()
        }

        print("SGPA and CGPA calculated successfully")  # Log successful calculation
        return Response({
            'semester_sgpa': round(acsgpa, 2),  # Return the updated SGPA
            'cgpa': round(minor_cgpa, 2),
            'updated_grades': updated_grades  # Include updated grades in the response
        }, status=status.HTTP_200_OK)

    except Exception as e:
        print("An error occurred:", e)  # Print the error
        return Response(
            {'error': f'An unexpected error occurred: {str(e)}'},
            status=status.HTTP_400_BAD_REQUEST
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_minor_status(request):
    """
    Check if the user is a minor or honor student.
    """
    try:
        user = request.user
        is_minor_student = user.is_minor  # Assuming you have this field in your CustomUser model
        is_honor_student = user.is_honors  # Assuming you have this field in your CustomUser model
        return Response({
            'is_minor_student': is_minor_student,
            'is_honor_student': is_honor_student
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_minor_subjects(request):
    """
    Returns the list of minor and honor subjects and credits for each semester based on the user's degree.
    """
    try:
        user = request.user
        degree = user.degree
        print("User degree:", degree)  # Log the user's degree

        minor_subjects = MINOR.get(degree, {})
        honor_subjects = HONOR.get(degree, {})

        if not minor_subjects and not honor_subjects:
            print("Invalid degree or no minor/honor subjects available")  # Log the error condition
            return Response({'error': 'Invalid degree or no minor/honor subjects available'}, status=status.HTTP_400_BAD_REQUEST)

        response_data = {
            'Minor': minor_subjects,
            'Honor': honor_subjects
        }
        print("Response data:", response_data)  # Print the response data
        return Response(response_data)
    except Exception as e:
        print("Error in get_minor_subjects:", str(e))  # Log the error
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])  # Ensure this line is present
def summury(request):
    user = request.user
    print("User:", user)
    print("User CGPA:", user.cgpa)  # Log the user's CGPA
   

    # Safely aggregate best and worst semester GPAs
    best_semester = user.semesters.aggregate(Max('gpa'))['gpa__max'] or 0.0
    worst_semester = user.semesters.aggregate(Min('gpa'))['gpa__min'] or 0.0

    # Count toppers and supply grades
    topper_count = Subject.objects.filter(semester__user=user, grade__grade='S').count()
    supply_count = Subject.objects.filter(semester__user=user, grade__grade='F').count()

    # Calculate total credits and earned credits
    semesters = Semester.objects.filter(user=user)
    total_credits = [semester.total_credits or 0 for semester in semesters]
    earned_credits = [semester.earn_credits or 0 for semester in semesters]
    print("credits",earned_credits)
    # Calculate yearback required credits
    current_semester = int(user.semester.split('_')[-1])
    print("Current semester:", current_semester)  # Log current semester
    yearback_required = 0


    if current_semester <= 4:
        first_two_semesters_total = sum(total_credits[:2])
        print(first_two_semesters_total)
        first_two_semesters_earned = sum(earned_credits[:2])
        print(first_two_semesters_earned)
        difference = first_two_semesters_total - first_two_semesters_earned
        print(difference,'diff')
        yearback_required = max(0,  difference-17)
    elif current_semester <= 6:
        first_four_semesters_total = sum(total_credits[:4])
        first_four_semesters_earned = sum(earned_credits[:4])
        difference = first_four_semesters_total - first_four_semesters_earned
        yearback_required = max(0, difference-41)

    # Calculate SGPA required for upcoming semesters to achieve targeted CGPA
    targeted_cgpa = user.targeted_cgpa or 0.0
    print("Targeted CGPA:", targeted_cgpa)  # Log targeted CGPA
    sgpa_required = None
    total_semesters = 8  # Assuming 8 semesters in total
    if targeted_cgpa and current_semester < total_semesters:
        remaining_semesters = total_semesters - current_semester
        print("Remaining semesters:", remaining_semesters)  # Log remaining semesters
        cgpsum = user.cgpa * current_semester  # Use the user's CGPA field
        print("CGPA sum:", cgpsum)
        required_cgpa_sum = targeted_cgpa * total_semesters
        print("Required CGPA sum:", required_cgpa_sum)
        sgpa_required = (required_cgpa_sum - cgpsum) / remaining_semesters
        sgpa_required = round(sgpa_required, 2)
        if sgpa_required > 10:
            sgpa_required = "not achievable"
        print("SGPA required:", sgpa_required)  # Log SGPA required

    return Response({
        'best_semester': best_semester,
        'worst_semester': worst_semester,
        'topper_count': topper_count,
        'supply_count': supply_count,
        'current_semester': user.semester,
        'total_credits': total_credits,
        'earned_credits': earned_credits,
        'yearback_required': yearback_required,
        'sgpa_required': sgpa_required
    }, status=status.HTTP_200_OK)

@api_view(['POST'])  # Ensure the method matches the frontend request
@permission_classes([IsAuthenticated])
def export_gpa_data(request):
    try:
        print("Request Method:", request.method)  # Log the HTTP method
        print("Request Headers:", request.headers)  # Log the request headers
        print("Request Body:", request.body.decode('utf-8'))  # Log the raw request body

        user = request.user
        print("User:", user)  # Log the user making the request

        # Prepare user data
        user_data = {
            'name': user.get_full_name(),
            'degree': user.degree,
            'current_semester': user.semester,
            'cgpa': user.cgpa,
        }
        print("User Data:", user_data)  # Log user data

        # Prepare semester data
        semesters = []
        for semester in Semester.objects.filter(user=user).prefetch_related('subjects__grade'):
            subjects = []
            for subject in semester.subjects.all():
                subjects.append({
                    'name': subject.name,
                    'credits': subject.credits,
                    'grade': subject.grade.grade if subject.grade else 'N/A'
                })
            semesters.append({
                'semester': semester.semester,
                'gpa': semester.gpa or 'N/A',
                'subjects': subjects
            })
        response_data = {
            'user': user_data,
            'semesters': semesters
        }
        print("Response Data:", response_data)  # Log the response data

        return Response(response_data, status=status.HTTP_200_OK)
    except Exception as e:
        print("Error:", str(e))  # Log the error
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def fetch_students_by_faculty(request):
    try:
        user = request.user
        if not hasattr(user, 'college_code') or not user.college_code:
            return Response({'error': 'Faculty does not have valid college code'}, 
                         status=status.HTTP_400_BAD_REQUEST)

        students = CustomUser.objects.filter(
            KTUID__icontains=user.college_code,  # Changed field name
            is_faculty=False
        )

        student_data = [
            {
                'name': student.get_full_name(),
                'KTUID': student.KTUID,  # Changed field name
                'degree': student.degree,
                'semester': student.semester,
                'cgpa': student.cgpa
            }
            for student in students
        ]
        response_data = {'students': student_data}
        print("Response data:", response_data)  # Log the response
        return Response({'students': student_data}, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def predict_cgpa(request):
    """
    Predict CGPA based on user input features
    """
    try:
        data = request.data
        user = request.user
        
        # Extract features from request data
        features = {
            'num_S': data.get('num_S', 0),
            'num_A': data.get('num_A', 0),
            'num_B': data.get('num_B', 0),
            'num_C': data.get('num_C', 0),
            'num_D': data.get('num_D', 0),
            'num_F': data.get('num_F', 0),
            'study_hours_per_week': data.get('study_hours_per_week', 12),
            'participated_in_events': data.get('participated_in_events', 0),
            'project_count': data.get('project_count', 0),
            'internship_experience': data.get('internship_experience', 0),
            'travel_time_minutes': data.get('travel_time_minutes', 30),
            'lives_in_pg_or_hostel': data.get('lives_in_pg_or_hostel', 0),
            'previous_board_cgpa': data.get('previous_board_cgpa', 8.0)
        }
        
        # Validate input ranges
        if not (0 <= features['study_hours_per_week'] <= 25):
            return Response({'error': 'Study hours per week must be between 0 and 25'}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        if not (5.0 <= features['previous_board_cgpa'] <= 10.0):
            return Response({'error': 'Previous board CGPA must be between 5.0 and 10.0'}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        # Make prediction
        try:
            predicted_cgpa = cgpa_predictor.predict_cgpa(features)
            
            # Save prediction history
            CGPAPrediction.objects.create(
                user=user,
                predicted_cgpa=predicted_cgpa,
                num_S=features['num_S'],
                num_A=features['num_A'],
                num_B=features['num_B'],
                num_C=features['num_C'],
                num_D=features['num_D'],
                num_F=features['num_F'],
                study_hours_per_week=features['study_hours_per_week'],
                participated_in_events=bool(features['participated_in_events']),
                project_count=features['project_count'],
                internship_experience=bool(features['internship_experience']),
                travel_time_minutes=features['travel_time_minutes'],
                lives_in_pg_or_hostel=bool(features['lives_in_pg_or_hostel']),
                previous_board_cgpa=features['previous_board_cgpa'],
                prediction_type='manual'
            )
            
            return Response({
                'predicted_cgpa': predicted_cgpa,
                'input_features': features,
                'message': 'CGPA prediction successful'
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            print(f"Prediction error: {e}")
            return Response({'error': f'Prediction failed: {str(e)}'}, 
                          status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    except Exception as e:
        print(f"General error in predict_cgpa: {e}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def predict_cgpa_from_user_data(request):
    """
    Predict CGPA using user's existing academic data combined with additional input
    """
    try:
        user = request.user
        data = request.data
        
        # Get user's existing semester data
        user_semesters = Semester.objects.filter(user=user)
        
        # Calculate grade distribution from user's data
        grade_counts = cgpa_predictor.calculate_grade_distribution(user_semesters)
        
        # Use provided features or defaults
        features = {
            'num_S': data.get('num_S', grade_counts['S']),
            'num_A': data.get('num_A', grade_counts['A']),
            'num_B': data.get('num_B', grade_counts['B']),
            'num_C': data.get('num_C', grade_counts['C']),
            'num_D': data.get('num_D', grade_counts['D']),
            'num_F': data.get('num_F', grade_counts['F']),
            'study_hours_per_week': data.get('study_hours_per_week', 12),
            'participated_in_events': data.get('participated_in_events', 0),
            'project_count': data.get('project_count', 0),
            'internship_experience': data.get('internship_experience', 0),
            'travel_time_minutes': data.get('travel_time_minutes', 30),
            'lives_in_pg_or_hostel': data.get('lives_in_pg_or_hostel', 0),
            'previous_board_cgpa': data.get('previous_board_cgpa', 8.0)
        }
        
        # Make prediction
        predicted_cgpa = cgpa_predictor.predict_cgpa(features)
        
        # Save prediction history
        CGPAPrediction.objects.create(
            user=user,
            predicted_cgpa=predicted_cgpa,
            actual_cgpa=user.cgpa,
            num_S=features['num_S'],
            num_A=features['num_A'],
            num_B=features['num_B'],
            num_C=features['num_C'],
            num_D=features['num_D'],
            num_F=features['num_F'],
            study_hours_per_week=features['study_hours_per_week'],
            participated_in_events=bool(features['participated_in_events']),
            project_count=features['project_count'],
            internship_experience=bool(features['internship_experience']),
            travel_time_minutes=features['travel_time_minutes'],
            lives_in_pg_or_hostel=bool(features['lives_in_pg_or_hostel']),
            previous_board_cgpa=features['previous_board_cgpa'],
            prediction_type='from_user_data'
        )
        
        return Response({
            'predicted_cgpa': predicted_cgpa,
            'current_cgpa': user.cgpa or 0.0,
            'grade_distribution': grade_counts,
            'input_features': features,
            'message': 'CGPA prediction based on user data successful'
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        print(f"Error in predict_cgpa_from_user_data: {e}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_prediction_form_data(request):
    """
    Get user's current academic data for pre-filling the prediction form
    """
    try:
        user = request.user
        user_semesters = Semester.objects.filter(user=user)
        
        # Calculate grade distribution from user's data
        grade_counts = cgpa_predictor.calculate_grade_distribution(user_semesters)
        
        # Prepare form data
        form_data = {
            'current_cgpa': user.cgpa or 0.0,
            'current_semester': user.semester,
            'degree': user.degree,
            'grade_distribution': grade_counts,
            'default_features': {
                'num_S': grade_counts['S'],
                'num_A': grade_counts['A'],
                'num_B': grade_counts['B'],
                'num_C': grade_counts['C'],
                'num_D': grade_counts['D'],
                'num_F': grade_counts['F'],
                'study_hours_per_week': 12,
                'participated_in_events': 0,
                'project_count': 0,
                'internship_experience': 0,
                'travel_time_minutes': 30,
                'lives_in_pg_or_hostel': 0,
                'previous_board_cgpa': 8.0
            }
        }
        
        return Response(form_data, status=status.HTTP_200_OK)
    
    except Exception as e:
        print(f"Error in get_prediction_form_data: {e}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def train_prediction_model(request):
    """
    Train/retrain the CGPA prediction model (admin only)
    """
    try:
        user = request.user
        
        # Check if user is admin/faculty (you can modify this condition based on your user model)
        if not (user.is_staff or getattr(user, 'is_faculty', False)):
            return Response({'error': 'Permission denied. Admin access required.'}, 
                          status=status.HTTP_403_FORBIDDEN)
        
        # Train the model
        performance_metrics = cgpa_predictor.train_model()
        
        return Response({
            'message': 'Model training completed successfully',
            'performance_metrics': performance_metrics
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        print(f"Error in train_prediction_model: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_prediction_history(request):
    """
    Get user's CGPA prediction history
    """
    try:
        user = request.user
        predictions = CGPAPrediction.objects.filter(user=user)[:10]  # Last 10 predictions
        
        prediction_data = []
        for prediction in predictions:
            prediction_data.append({
                'id': prediction.id,
                'predicted_cgpa': prediction.predicted_cgpa,
                'actual_cgpa': prediction.actual_cgpa,
                'created_at': prediction.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                'prediction_type': prediction.prediction_type,
                'input_features': {
                    'num_S': prediction.num_S,
                    'num_A': prediction.num_A,
                    'num_B': prediction.num_B,
                    'num_C': prediction.num_C,
                    'num_D': prediction.num_D,
                    'num_F': prediction.num_F,
                    'study_hours_per_week': prediction.study_hours_per_week,
                    'participated_in_events': prediction.participated_in_events,
                    'project_count': prediction.project_count,
                    'internship_experience': prediction.internship_experience,
                    'travel_time_minutes': prediction.travel_time_minutes,
                    'lives_in_pg_or_hostel': prediction.lives_in_pg_or_hostel,
                    'previous_board_cgpa': prediction.previous_board_cgpa,
                }
            })
        
        return Response({
            'predictions': prediction_data,
            'total_count': CGPAPrediction.objects.filter(user=user).count()
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        print(f"Error in get_prediction_history: {e}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
