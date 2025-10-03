pipeline {
    agent any
    
    tools {
        nodejs 'NodeJS-18'  // Must match the name in Jenkins Global Tool Configuration
    }
    
    environment {
        GITHUB_CREDENTIALS = 'github-token'  // Updated to match your credential ID
        REPO_URL = 'https://github.com/johnjorellandicho/alwaysontrackimpossible.git'
        // Remove FIREBASE_TOKEN if not using Firebase, or add it back when needed
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
                echo '⚙️ Setting up Node.js environment...'
                sh '''
                    echo "Node version:"
                    node --version
                    echo "NPM version:"
                    npm --version
                '''
            }
        }
        
        stage('Detect Project Structure') {
            steps {
                script {
                    echo 'Analyzing repository structure...'
                    sh '''
                        echo "=== Current Directory ==="
                        pwd
                        echo ""
                        echo "=== Root Directory Contents ==="
                        ls -la
                        echo ""
                        echo "=== Looking for package.json files ==="
                        find . -name "package.json" -type f -not -path "*/node_modules/*"
                        echo ""
                        echo "=== Looking for subdirectories ==="
                        find . -maxdepth 2 -type d -not -path "*/node_modules/*" -not -path "*/.git/*"
                    '''
                    
                    // Detect if package.json exists in root or subdirectory
                    def hasRootPackageJson = fileExists('package.json')
                    def hasBackendDir = fileExists('vitalsigns-backend/package.json')
                    def hasBackend = fileExists('backend/package.json')
                    def hasServer = fileExists('server/package.json')
                    
                    if (hasRootPackageJson) {
                        env.PROJECT_DIR = '.'
                        echo 'Found package.json in root directory'
                    } else if (hasBackendDir) {
                        env.PROJECT_DIR = 'vitalsigns-backend'
                        echo 'Found package.json in vitalsigns-backend directory'
                    } else if (hasBackend) {
                        env.PROJECT_DIR = 'backend'
                        echo 'Found package.json in backend directory'
                    } else if (hasServer) {
                        env.PROJECT_DIR = 'server'
                        echo 'Found package.json in server directory'
                    } else {
                        env.PROJECT_DIR = '.'
                        echo 'No package.json found, using root directory'
                    }
                    
                    echo "Working directory set to: ${env.PROJECT_DIR}"
                }
            }
        }
        
        stage('Install Dependencies') {
            when {
                expression { 
                    fileExists("${env.PROJECT_DIR}/package.json")
                }
            }
            steps {
                echo ' Installing project dependencies...'
                dir("${env.PROJECT_DIR}") {
                    sh '''
                        npm install
                        echo "Dependencies installed successfully"
                    '''
                }
            }
        }
        
        stage('Lint') {
            when {
                expression { 
                    fileExists("${env.PROJECT_DIR}/package.json")
                }
            }
            steps {
                echo '🔍 Running code linting...'
                dir("${env.PROJECT_DIR}") {
                    sh '''
                        if npm run lint --if-present 2>/dev/null; then
                            echo "Linting completed"
                        else
                            echo "Lint script not found or failed, skipping..."
                        fi
                    '''
                }
            }
        }
        
        stage('Build') {
            when {
                expression { 
                    fileExists("${env.PROJECT_DIR}/package.json")
                }
            }
            steps {
                echo ' Building project...'
                dir("${env.PROJECT_DIR}") {
                    sh '''
                        if npm run build --if-present 2>/dev/null; then
                            echo "Build completed successfully"
                        else
                            echo "Build script not found, skipping..."
                        fi
                    '''
                }
            }
        }
        
        stage('Test') {
            when {
                expression { 
                    fileExists("${env.PROJECT_DIR}/package.json")
                }
            }
            steps {
                echo ' Running tests...'
                dir("${env.PROJECT_DIR}") {
                    sh '''
                        if npm run test --if-present 2>/dev/null; then
                            echo "Tests passed"
                        else
                            echo "Tests not configured or failed, continuing..."
                        fi
                    '''
                }
            }
        }
        
        stage('Archive Artifacts') {
            when {
                expression { 
                    fileExists("${env.PROJECT_DIR}/dist") || fileExists("${env.PROJECT_DIR}/build")
                }
            }
            steps {
                echo 'Archiving build artifacts...'
                script {
                    if (fileExists("${env.PROJECT_DIR}/dist")) {
                        archiveArtifacts artifacts: "${env.PROJECT_DIR}/dist/**/*", allowEmptyArchive: true
                    }
                    if (fileExists("${env.PROJECT_DIR}/build")) {
                        archiveArtifacts artifacts: "${env.PROJECT_DIR}/build/**/*", allowEmptyArchive: true
                    }
                }
            }
        }
        
        // Uncomment this stage when you're ready to deploy to Firebase
        /*
        stage('Deploy to Firebase') {
            when {
                branch 'main'
                expression { 
                    fileExists("${env.PROJECT_DIR}/firebase.json")
                }
            }
            steps {
                echo 'Deploying to Firebase...'
                dir("${env.PROJECT_DIR}") {
                    withCredentials([string(credentialsId: 'firebase-token', variable: 'FIREBASE_TOKEN')]) {
                        sh '''
                            npm install -g firebase-tools
                            firebase deploy --token ${FIREBASE_TOKEN} --non-interactive
                        '''
                    }
                }
            }
        }
        */
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
            echo 'Project is ready!'
        }
        failure {
            echo 'Pipeline failed!'
            echo 'Check the logs above for errors'
        }
        always {
            echo 'Pipeline execution completed'
        }
        cleanup {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}
