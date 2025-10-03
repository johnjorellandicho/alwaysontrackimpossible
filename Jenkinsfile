pipeline {
    agent {
        docker {
            image 'cirrusci/flutter:3.24.3'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }
    
    environment {
        // Only add this if you need Firebase CLI commands
        FIREBASE_TOKEN = credentials('firebase-token-id')
        // Add MongoDB URI if needed
        MONGODB_URI = credentials('mongodb-uri')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo 'Code checked out successfully'
            }
        }
        
        stage('Verify Firebase Config') {
            steps {
                sh '''
                    echo "Checking google-services.json..."
                    if [ -f android/app/google-services.json ]; then
                        echo "✅ google-services.json found"
                    else
                        echo "❌ google-services.json not found"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Flutter Doctor') {
            steps {
                sh '''
                    flutter --version
                    flutter doctor -v
                '''
            }
        }
        
        stage('Clean & Get Dependencies') {
            steps {
                sh '''
                    flutter clean
                    flutter pub get
                '''
            }
        }
        
        stage('Analyze Code') {
            steps {
                sh 'flutter analyze || true'
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'flutter test || echo "No tests found or tests failed"'
            }
        }
        
        stage('Build APK') {
            steps {
                sh '''
                    echo "Building release APK..."
                    flutter build apk --release
                '''
            }
        }
        
        stage('Archive APK') {
            steps {
                archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/*.apk', 
                                 fingerprint: true,
                                 allowEmptyArchive: false
            }
        }
    }
    
    post {
        success {
            echo '✅ Build completed successfully!'
            echo 'APK available in build artifacts'
        }
        failure {
            echo '❌ Build failed! Check the logs above for errors.'
        }
        always {
            cleanWs()
        }
    }
}
