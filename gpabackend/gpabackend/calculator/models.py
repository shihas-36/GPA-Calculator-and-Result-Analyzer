from django.db import models
from accounts.models import CustomUser  # Import the CustomUser model from accounts

class Semester(models.Model):
    """
    Model to store semester information for each user.
    """
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='semesters')
    semester = models.CharField(max_length=20, default='semester_1')  # Use CharField with default value
    gpa = models.FloatField(null=True, blank=True)  # GPA for this semester
    
    minor_gpa = models.FloatField(null=True, blank=True)    # SGPA with minor courses
    minor_cgpa = models.FloatField(null=True, blank=True)    # SGPA with minor courses
    total_credits = models.IntegerField(default=0)  # Add total_credits field
    total_points = models.FloatField(default=0.0)
    complete_courses = models.IntegerField(default=0)  # Add complete_courses field
    minor_credits = models.IntegerField(default=0)  # Add total_credits field
    earn_credits = models.IntegerField(default=0)  # Add total_credits field
    minor_points = models.FloatField(default=0.0)  # Add total_points field
    
    class Meta:
        unique_together = ('user', 'semester')  # Ensure unique semesters per user

    def __str__(self):
        return f"{self.user.username} - Semester {self.semester}"

class Subject(models.Model):
    """
    Model to store subjects and their credits for each semester.
    """
    semester = models.ForeignKey(Semester, related_name='subjects', on_delete=models.CASCADE)
    name = models.CharField(max_length=100)  # e.g., "Physics", "Maths"
    credits = models.IntegerField()  # Credits for the subject

    class Meta:
        unique_together = ('semester', 'name')  # Ensure unique subjects per semester

    def __str__(self):
        return f"{self.name} ({self.credits} credits)"

class Grade(models.Model):
    """
    Model to store grades for each subject in a semester.
    """
    subject = models.OneToOneField(Subject, related_name='grade', on_delete=models.CASCADE)
    grade = models.CharField(max_length=2, choices=[
        ('S', 'S'), ('A', 'A'), ('B', 'B'),
        ('C', 'C'), ('D', 'D'), ('F', 'F')
    ])  # Grade for the subject

    def __str__(self):
        return f"{self.subject.name} - {self.grade}"

class GradeDetail(models.Model):
    """
    Model to store detailed grade information for each subject.
    This is separate from the main Grade model to avoid overwriting GPA-related data.
    """
    subject = models.ForeignKey(Subject, related_name='grade_details', on_delete=models.CASCADE)
    marks = models.FloatField()  # Store the marks for the subject
    grade = models.CharField(max_length=2, choices=[
        ('S', 'S'), ('A+', 'A+'), ('A', 'A'), ('B+', 'B+'),
        ('B', 'B'), ('C+', 'C+'), ('C', 'C'), ('D+', 'D+'),
        ('P', 'P'), ('F', 'F')
    ])  # Grade for the subject

    def __str__(self):
        return f"{self.subject.name} - Marks: {self.marks}, Grade: {self.grade}"

class CGPAPrediction(models.Model):
    """
    Model to store CGPA prediction history
    """
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='cgpa_predictions')
    predicted_cgpa = models.FloatField()
    actual_cgpa = models.FloatField(null=True, blank=True)  # To compare with actual results later
    
    # Input features used for prediction
    num_S = models.IntegerField(default=0)
    num_A = models.IntegerField(default=0)
    num_B = models.IntegerField(default=0)
    num_C = models.IntegerField(default=0)
    num_D = models.IntegerField(default=0)
    num_F = models.IntegerField(default=0)
    study_hours_per_week = models.FloatField(default=12.0)
    participated_in_events = models.BooleanField(default=False)
    project_count = models.IntegerField(default=0)
    internship_experience = models.BooleanField(default=False)
    travel_time_minutes = models.IntegerField(default=30)
    lives_in_pg_or_hostel = models.BooleanField(default=False)
    previous_board_cgpa = models.FloatField(default=8.0)
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    prediction_type = models.CharField(max_length=50, default='manual')  # 'manual' or 'from_user_data'
    
    def __str__(self):
        return f"{self.user.username} - Predicted CGPA: {self.predicted_cgpa} ({self.created_at})"

    class Meta:
        ordering = ['-created_at']

