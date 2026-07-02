pipeline {
    agent any
    // Параметры UI Jenkins
    parameters {
        choice(
            name: 'BUILD_TYPE', 
            choices: [
                'all', 
                'normal', 
                'coverage', 
                'asan', 
                'ubsan', 
                'fuzz', 
                'fuzz-bpf', 
                'fuzz-distributed'
            ], 
            description: 'Выберите тип сборки (all запускает всё параллельно)'
        )
    }

    // Настройки окружения
    environment {
        // Передаём параметр в bash-скрипт
        BUILD_TYPE = "${params.BUILD_TYPE}"
    }

    options {
        // Храним только последние 10 билдов
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Не делать параллельные запуски одной и той же джобы
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                // Скачиваем код из репозитория
                checkout scm
            }
        }

        stage('Run CI') {
            steps {
                echo "Запуск сборок: ${env.BUILD_TYPE}"
                sh '''
                    chmod +x ci/jenkins-runner.sh
                    ./ci/jenkins-runner.sh
                '''
            }
        }
    }

    post {
        success {
            echo 'Успешно'
        }
        failure {
            echo 'Неуспешно'
        }
    }
}