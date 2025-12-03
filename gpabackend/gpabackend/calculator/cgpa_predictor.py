import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import pickle
import os
from django.conf import settings

class CGPAPredictor:
    def __init__(self):
        self.model = None
        self.feature_columns = [
            'num_S', 'num_A', 'num_B', 'num_C', 'num_D', 'num_F', 
            'study_hours_per_week', 'participated_in_events', 'project_count', 
            'internship_experience', 'travel_time_minutes', 'lives_in_pg_or_hostel', 
            'previous_board_cgpa'
        ]
        self.model_path = os.path.join(settings.BASE_DIR, 'calculator', 'cgpa_model.pkl')
        
    def create_synthetic_dataset(self, n_students=500):
        """Create synthetic dataset for training the model"""
        np.random.seed(42)
        data = {
            'num_S': np.random.randint(0, 10, n_students),
            'num_A': np.random.randint(0, 10, n_students),
            'num_B': np.random.randint(0, 10, n_students),
            'num_C': np.random.randint(0, 8, n_students),
            'num_D': np.random.randint(0, 5, n_students),
            'num_F': np.random.randint(0, 3, n_students),
            'study_hours_per_week': np.random.normal(12, 4, n_students).clip(2, 25),
            'participated_in_events': np.random.choice([0, 1], n_students),
            'project_count': np.random.randint(0, 5, n_students),
            'internship_experience': np.random.choice([0, 1], n_students, p=[0.6, 0.4]),
            'travel_time_minutes': np.random.randint(10, 120, n_students),
            'lives_in_pg_or_hostel': np.random.choice([0, 1], n_students),
            'previous_board_cgpa': np.random.normal(8, 0.8, n_students).clip(5.0, 10.0),
        }

        df = pd.DataFrame(data)

        # Final CGPA calculation (mock formula)
        df['final_cgpa'] = (
            0.9 * df['num_S'] +
            0.6 * df['num_A'] +
            0.5 * df['num_B'] +
            0.6 * df['num_C'] -
            0.9 * df['num_F'] +
            0.03 * df['project_count'] +
            0.1 * df['internship_experience'] +
            0.02 * df['study_hours_per_week'] +
            0.02 * df['participated_in_events'] -
            0.05 * df['travel_time_minutes'] +
            0.15 * df['previous_board_cgpa']
        ).clip(5, 10)

        return df

    def train_model(self):
        """Train the CGPA prediction model"""
        # Create synthetic dataset
        df = self.create_synthetic_dataset()
        
        # Define input features and target
        X = df[self.feature_columns]
        y = df['final_cgpa']

        # Split into training and test sets
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        # Train Random Forest Regressor (best performing model from notebook)
        self.model = RandomForestRegressor(n_estimators=100, random_state=42)
        self.model.fit(X_train, y_train)

        # Evaluate model
        y_pred = self.model.predict(X_test)
        mae = mean_absolute_error(y_test, y_pred)
        rmse = np.sqrt(mean_squared_error(y_test, y_pred))
        r2 = r2_score(y_test, y_pred)

        print(f"Model Performance:")
        print(f"MAE: {mae:.4f}")
        print(f"RMSE: {rmse:.4f}")
        print(f"R²: {r2:.4f}")

        # Save the trained model
        self.save_model()
        
        return {
            'mae': mae,
            'rmse': rmse,
            'r2': r2
        }

    def save_model(self):
        """Save the trained model to disk"""
        if self.model:
            with open(self.model_path, 'wb') as f:
                pickle.dump(self.model, f)
            print(f"Model saved to {self.model_path}")

    def load_model(self):
        """Load the trained model from disk"""
        if os.path.exists(self.model_path):
            with open(self.model_path, 'rb') as f:
                self.model = pickle.load(f)
            print("Model loaded successfully")
            return True
        else:
            print("No saved model found. Training new model...")
            self.train_model()
            return True

    def predict_cgpa(self, input_features):
        """
        Predict CGPA based on input features
        
        Args:
            input_features (dict): Dictionary containing all required features
            
        Returns:
            float: Predicted CGPA
        """
        if self.model is None:
            self.load_model()

        # Ensure all required features are present
        feature_values = []
        for feature in self.feature_columns:
            if feature not in input_features:
                raise ValueError(f"Missing required feature: {feature}")
            feature_values.append(input_features[feature])

        # Make prediction
        prediction = self.model.predict([feature_values])[0]
        
        # Ensure prediction is within valid range (5.0 - 10.0)
        prediction = max(5.0, min(10.0, prediction))
        
        return round(prediction, 2)

    def calculate_grade_distribution(self, user_semesters):
        """
        Calculate grade distribution from user's semester data
        
        Args:
            user_semesters: QuerySet of user's semesters
            
        Returns:
            dict: Grade distribution counts
        """
        grade_counts = {'S': 0, 'A': 0, 'B': 0, 'C': 0, 'D': 0, 'F': 0}
        
        for semester in user_semesters:
            for subject in semester.subjects.all():
                if hasattr(subject, 'grade') and subject.grade:
                    grade = subject.grade.grade
                    # Map grades to simplified categories
                    if grade in ['S']:
                        grade_counts['S'] += 1
                    elif grade in ['A+', 'A']:
                        grade_counts['A'] += 1
                    elif grade in ['B+', 'B']:
                        grade_counts['B'] += 1
                    elif grade in ['C+', 'C']:
                        grade_counts['C'] += 1
                    elif grade in ['D+', 'P']:
                        grade_counts['D'] += 1
                    elif grade in ['F']:
                        grade_counts['F'] += 1
        
        return grade_counts

# Initialize the predictor instance
cgpa_predictor = CGPAPredictor()