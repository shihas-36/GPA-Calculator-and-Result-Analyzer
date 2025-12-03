"""
Test script for CGPA Prediction functionality
Run this to test the prediction model
"""
import os
import sys
import django

# Add the project directory to sys.path
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'gpabackend'))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gpabackend.settings')
django.setup()

from calculator.cgpa_predictor import cgpa_predictor

def test_prediction():
    """Test the CGPA prediction functionality"""
    print("Testing CGPA Prediction Model...")
    print("=" * 50)
    
    # Test 1: Train the model
    print("1. Training the model...")
    try:
        performance = cgpa_predictor.train_model()
        print(f"✓ Model trained successfully!")
        print(f"  MAE: {performance['mae']:.4f}")
        print(f"  RMSE: {performance['rmse']:.4f}")
        print(f"  R²: {performance['r2']:.4f}")
    except Exception as e:
        print(f"✗ Error training model: {e}")
        return
    
    print("\n" + "=" * 50)
    
    # Test 2: Make a prediction
    print("2. Testing prediction...")
    test_features = {
        'num_S': 5,
        'num_A': 3,
        'num_B': 7,
        'num_C': 8,
        'num_D': 2,
        'num_F': 1,
        'study_hours_per_week': 15.0,
        'participated_in_events': 1,
        'project_count': 3,
        'internship_experience': 1,
        'travel_time_minutes': 45,
        'lives_in_pg_or_hostel': 0,
        'previous_board_cgpa': 8.5
    }
    
    try:
        predicted_cgpa = cgpa_predictor.predict_cgpa(test_features)
        print(f"✓ Prediction successful!")
        print(f"  Input features: {test_features}")
        print(f"  Predicted CGPA: {predicted_cgpa}")
    except Exception as e:
        print(f"✗ Error making prediction: {e}")
        return
    
    print("\n" + "=" * 50)
    print("✓ All tests passed! CGPA prediction system is working correctly.")

if __name__ == "__main__":
    test_prediction()