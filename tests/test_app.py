import sys
import os
import unittest

# Add the project root directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../app')))

from main import app  # Now it will successfully import app.py from the 'app' folder

class FlaskAppTestCase(unittest.TestCase):

    def setUp(self):
        """Set up a test client before each test."""
        self.app = app.test_client()
        self.app.testing = True

    def test_home_endpoint(self):
        """Test 1: Verify home endpoint (/) returns 200 OK and correct JSON response."""
        response = self.app.get('/')
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {
            "message": "Welcome to the Flask application!",
            "status": "success"
        })

    def test_health_endpoint(self):
        """Test 2: Verify health endpoint (/health) returns 200 OK and healthy status."""
        response = self.app.get('/health')
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {
            "status": "healthy",
            "service": "flask-app"
        })

if __name__ == '__main__':
    unittest.main()