pipeline {
    agent any

    tools {
        nodejs "node16"
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
                sh 'npm install'
            }
        }

        stage('Build') {
            steps {
                sh 'npm run build'
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
            echo '✅ Build and Deployment Successful!'
        }
        failure {
            echo '❌ Build or Deployment Failed!'
        }
    }
}
