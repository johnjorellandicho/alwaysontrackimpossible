pipeline {
    agent {
        docker {
            image 'cirrusci/flutter:3.24.3'  // Flutter image with SDK pre-installed
        }
    }

    environment {
        FIREBASE_TOKEN = credentials('firebase-token')
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/johnjorellandicho/alwaysontrackimpossible.git',
                    credentialsId: 'github-credentials'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'flutter pub get'
            }
        }

        stage('Build APK') {
            steps {
                sh 'flutter build apk --release'
            }
        }

        stage('Deploy to Firebase') {
            steps {
                sh "npx firebase deploy --token $FIREBASE_TOKEN --non-interactive"
            }
        }
    }

    post {
        success {
            echo Flutter Build and Deployment Successful!'
        }
        failure {
            echo ' Build or Deployment Failed!'
        }
    }
}
