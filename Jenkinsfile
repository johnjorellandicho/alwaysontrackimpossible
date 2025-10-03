pipeline {
    agent any
    
    environment {
        FLUTTER_HOME = "${WORKSPACE}/flutter"
        PATH = "${FLUTTER_HOME}/bin:${PATH}"
    }
    
    stages {
        stage('Setup Flutter') {
            steps {
                sh '''
                    if [ ! -d "${FLUTTER_HOME}" ]; then
                        echo "Installing Flutter..."
                        git clone https://github.com/flutter/flutter.git -b stable ${FLUTTER_HOME}
                    else
                        echo "Flutter already installed, updating..."
                        cd ${FLUTTER_HOME}
                        git pull
                    fi
                    
                    flutter --version
                    flutter doctor
                    flutter precache
                '''
            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Verify Firebase Config') {
            steps {
                sh '''
                    if [ -f android/app/google-services.json ]; then
                        echo "✅ Firebase configuration found"
                    else
                        echo "❌ Firebase configuration missing"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Get Dependencies') {
            steps {
                sh 'flutter pub get'
            }
        }
        
        stage('Analyze Code') {
            steps {
                sh 'flutter analyze || true'
            }
        }
        
        stage('Build APK') {
            steps {
                sh 'flutter build apk --release'
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
            echo ' Build completed successfully!'
        }
        failure {
            echo ' Build failed!'
        }
    }
}
