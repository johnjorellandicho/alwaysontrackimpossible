pipeline {
    agent any
    
    environment {
        FLUTTER_HOME = '/var/jenkins_home/flutter'
        ANDROID_HOME = '/usr/local/android-sdk'
        PATH = "${FLUTTER_HOME}/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools:${PATH}"
        FIREBASE_TOKEN = credentials('firebase-token')
    }
    
    stages {
        stage('Install Flutter') {
            steps {
                echo 'Checking and installing Flutter...'
                sh '''
                    if [ ! -d "${FLUTTER_HOME}" ]; then
                        echo "Flutter not found. Installing..."
                        git clone https://github.com/flutter/flutter.git -b stable ${FLUTTER_HOME}
                    else
                        echo "Flutter already installed. Updating..."
                        cd ${FLUTTER_HOME}
                        git pull
                    fi
                    
                    ${FLUTTER_HOME}/bin/flutter --version
                    ${FLUTTER_HOME}/bin/flutter doctor -v
                    ${FLUTTER_HOME}/bin/flutter config --no-analytics
                '''
            }
        }
        
        stage('Flutter Setup') {
            steps {
                echo 'Setting up Flutter environment...'
                sh '''
                    flutter pub get
                    flutter clean
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                echo 'Running unit and widget tests...'
                sh '''
                    flutter test --coverage
                    flutter analyze
                '''
            }
        }
        
        stage('Build Android APK') {
            steps {
                echo 'Building Android APK...'
                sh '''
                    flutter build apk --release
                '''
            }
        }
        
        stage('Build iOS (Optional)') {
            when {
                expression { return fileExists('ios/') }
            }
            steps {
                echo 'Building iOS app...'
                sh '''
                    flutter build ios --release --no-codesign
                '''
            }
        }
        
        stage('Arduino Firmware Check') {
            steps {
                echo 'Validating Arduino firmware...'
                sh '''
                    # Check if Arduino CLI is installed
                    if command -v arduino-cli &> /dev/null; then
                        cd arduino-firmware
                        arduino-cli compile --fqbn esp32:esp32:esp32 .
                    else
                        echo "Arduino CLI not found, skipping firmware compilation"
                    fi
                '''
            }
        }
        
        stage('Deploy to Firebase (Staging)') {
            when {
                branch 'develop'
            }
            steps {
                echo 'Deploying to Firebase staging...'
                sh '''
                    npm install -g firebase-tools
                    firebase deploy --only hosting --token ${FIREBASE_TOKEN} --project alwaysontrack-staging
                '''
            }
        }
        
        stage('Deploy to Firebase (Production)') {
            when {
                branch 'main'
            }
            steps {
                echo 'Deploying to Firebase production...'
                sh '''
                    npm install -g firebase-tools
                    firebase deploy --only hosting,database --token ${FIREBASE_TOKEN} --project alwaysontrack-prod
                '''
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                echo 'Archiving build artifacts...'
                archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/*.apk', 
                                 allowEmptyArchive: true
            }
        }
        
        stage('Code Coverage Report') {
            steps {
                echo 'Publishing coverage reports...'
                publishHTML([
                    reportDir: 'coverage',
                    reportFiles: 'index.html',
                    reportName: 'Coverage Report'
                ])
            }
        }
    }
    
    post {
        success {
            echo 'Build successful!'
            emailext(
                subject: "AlwaysOnTrack Build Success - ${env.BUILD_NUMBER}",
                body: "Build completed successfully. Check console output at ${env.BUILD_URL}",
                to: 'team@impossible.com'
            )
        }
        failure {
            echo 'Build failed!'
            emailext(
                subject: "AlwaysOnTrack Build Failed - ${env.BUILD_NUMBER}",
                body: "Build failed. Check console output at ${env.BUILD_URL}",
                to: 'team@impossible.com'
            )
        }
        always {
            cleanWs()
        }
    }
}
