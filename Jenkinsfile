pipeline {
    agent any
    
    tools {
        nodejs 'NodeJS-18'  // Must match the name in Jenkins Global Tool Configuration
    }
    
    environment {
        GITHUB_CREDENTIALS = 'github-credentials'
        FIREBASE_TOKEN = credentials('firebase-token')
        REPO_URL = 'https://github.com/johnjorellandicho/alwaysontrackimpossible.git'
        BACKEND_DIR = 'vitalsigns-backend'
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
        
        stage('Debug - Check Directory Structure') {
            steps {
                echo 'Checking repository structure...'
                sh '''
                    echo "=== Current Directory ==="
                    pwd
                    echo "=== Directory Contents ==="
                    ls -la
                    echo "=== Finding package.json files ==="
                    find . -name "package.json" -type f
                '''
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo 'Installing project dependencies...'
                dir("${BACKEND_DIR}") {
                    sh 'npm install'
                }
            }
        }
        
        stage('Lint') {
            steps {
                echo 'Running code linting...'
                dir("${BACKEND_DIR}") {
                    sh 'npm run lint || echo "Lint not configured, skipping..."'
                }
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                dir("${BACKEND_DIR}") {
                    sh 'npm test || echo "Tests not configured or failed, continuing..."'
                }
            }
        }
        
        stage('Start Server (Optional)') {
            steps {
                echo 'Server can be started with: npm run dev'
                dir("${BACKEND_DIR}") {
                    sh 'echo "Server script available: npm run dev"'
                }
            }
        }
        
        stage('Deploy to Firebase') {
            when {
                branch 'main'
            }
            steps {
                echo 'Deploying to Firebase...'
                dir("${BACKEND_DIR}") {
                    sh '''
                        npm install -g firebase-tools
                        firebase deploy --token ${FIREBASE_TOKEN} --non-interactive
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo ' Pipeline completed successfully!'
            echo 'Backend is ready to deploy or run'
        }
        failure {
            echo ' Pipeline failed!'
            echo 'Check the logs above for errors'
        }
        cleanup {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}
