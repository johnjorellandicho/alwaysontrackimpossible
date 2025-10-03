pipeline {
    agent {
        docker {
            // ✅ Use a Docker image that already has Flutter + Android SDK
            image 'cirrusci/flutter:latest'
            args '-u root:root'  // ensures we have permission if needed
        }
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/johnjorellandicho/alwaysontrackimpossible.git'
            }
        }

        stage('Flutter Version') {
            steps {
                sh 'flutter --version'
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

        stage('Archive APK') {
            steps {
                archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/app-release.apk', fingerprint: true
            }
        }
    }
}
