pipeline {
    agent any

    environment {
        ANDROID_HOME = "/var/jenkins_home/android-sdk"
        ANDROID_SDK_ROOT = "/var/jenkins_home/android-sdk"
        PATH = "$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    sudo apt-get update
                    sudo apt-get install -y curl unzip zip clang cmake ninja-build pkg-config
                '''
            }
        }

        stage('Setup Android SDK') {
            steps {
                sh '''
                    mkdir -p $ANDROID_HOME/cmdline-tools
                    cd $ANDROID_HOME/cmdline-tools

                    if [ ! -d "latest" ]; then
                      echo "Downloading Android SDK Command-line tools..."
                      curl -o commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
                      unzip -q commandlinetools.zip -d .
                      mv cmdline-tools latest
                      rm commandlinetools.zip
                    fi

                    echo "Accepting SDK licenses..."
                    yes | sdkmanager --licenses

                    echo "Installing required SDK packages..."
                    sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0"
                '''
            }
        }

        stage('Setup Flutter') {
            steps {
                sh '''
                    if [ ! -d "$HOME/flutter" ]; then
                        echo "Installing Flutter..."
                        git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter
                    fi
                    export PATH="$HOME/flutter/bin:$PATH"
                    flutter doctor -v
                '''
            }
        }

        stage('Build APK') {
            steps {
                sh '''
                    export PATH="$HOME/flutter/bin:$PATH"
                    flutter pub get
                    flutter build apk --release
                '''
            }
        }

        stage('Archive APK') {
            steps {
                archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/app-release.apk', fingerprint: true
            }
        }
    }
}
