pipeline {
    agent any
    
    tools {
        nodejs 'NodeJS-18'  // Must match the name in Jenkins Global Tool Configuration
    }
    
    environment {
        GITHUB_CREDENTIALS = 'github-credentials'
        FIREBASE_TOKEN = credentials('firebase-token')
        REPO_URL = 'https://github.com/johnjorellandicho/alwaysontrackimpossible.git'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from repository...'
                git branch: 'main',
                    credentialsId: "${GITHUB_CREDENTIALS}",
                    url: "${REPO_URL}"
            }
        }
        
        stage('Environment Setup') {
            steps {
                echo 'Setting up Node.js environment...'
                sh '''
                    node --version
                    npm --version
                '''
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo 'Installing project dependencies...'
                sh 'npm ci'
            }
        }
        
        stage('Lint') {
            steps {
                echo 'Running code linting...'
                sh 'npm run lint || true'
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building the application...'
                sh 'npm run build'
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                sh 'npm test || true'
            }
        }
        
        stage('Deploy to Firebase') {
            when {
                branch 'main'
            }
            steps {
                echo 'Deploying to Firebase...'
                sh '''
                    npm install -g firebase-tools
                    firebase deploy --token ${FIREBASE_TOKEN} --non-interactive
                '''
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
            // Add notification here (email, Slack, etc.)
        }
        failure {
            echo 'Pipeline failed!'
            // Add notification here
        }
        cleanup {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}
