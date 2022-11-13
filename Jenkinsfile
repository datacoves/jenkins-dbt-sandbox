pipeline {
    agent any
//     agent {
//         docker {
//             image 'datacoves/ci-basic:0.5'
//             registryUrl 'https://artifactory.somecompany.com'
//             registryCredentialsId 'artifactory'
//         }
//     }

    environment {
        PROJECT_HOME = """${pwd()}"""
        DBT_PROFILES_DIR = """${pwd()}/automate/dbt"""
        DBT_HOME = """${pwd()}/transform/"""
        DBT_DATABASE = 'DEV_DW_DATABASE'
        DBT_SNOWFLAKE_ACCOUNT = 'snowflake-prod'
        SNOWFLAKE_CREDENTIALS_ID = 'jenkins-snowflake-creds'
        DBT_SNOWFLAKE_ROLE = 'DBT_RUNNER'
        DBT_SNOWFLAKE_WAREHOUSE = 'DEV_DATA_WAREHOUSE'
        PRE_COMMIT_HOME = """${pwd(tmp: true)}"""

        EMAIL_RECIPIENTS = """dev@somecompany.com"""
        EMAIL_SUBJECT = """${env.JOB_NAME} build #${env.BUILD_NUMBER}"""
    }

    stages {
        // TODO
        // stage('Determine Snowflake Account'){
        //     DBT_SNOWFLAKE_ACCOUNT
        // }

        // Validates that PR is opened against the right target branch
        stage('Validate Branch Names') {
            //when { changeRequest() }
            when { equals(actual: 1, expected: 1) }
            steps {
                withCredentials([usernamePassword(credentialsId: "${SNOWFLAKE_CREDENTIALS_ID}", passwordVariable: 'DBT_PASSWORD', usernameVariable: 'DBT_USER')]) {
                    sh '''
                        python3 automate/validate_branch_names.py `git rev-list --left-right --count origin/main | awk \'{print ""$1""}\'`
                    '''
                }
            }
            post {
                failure {
                    script {
                        sh '''
                            sendmail ${EMAIL_RECIPIENTS} -t <<EOF
                            Subject: [Jenkins] Validate Branch Names Failed - ${EMAIL_SUBJECT}
                            EOF
                        '''
                    }
                }
            }

        }

        // Feature to release branch
        stage('Feature to Release Tests') {
            //when { changeRequest target: "release/*", comparator: "GLOB" }
            when { equals(actual: 1, expected: 1) }
            steps {
                withCredentials([usernamePassword(credentialsId: "${SNOWFLAKE_CREDENTIALS_ID}", passwordVariable: 'DBT_PASSWORD', usernameVariable: 'DBT_USER')]) {
                    sh label: "Install dbt packages", script: '''
                        # Install dbt packages *****
                        cd $DBT_HOME
                        dbt deps
                    '''
                    sh label: "Create PR database", script: '''
                        # Create PR database *****
                        cd $PROJECT_HOME
                        PREV_DBT_SNOWFLAKE_ROLE=${DBT_SNOWFLAKE_ROLE}
                        export DBT_SNOWFLAKE_ROLE='JENKINS_DBT_RUNNER'
                        ./secure/create_snowflake_objects.py -s warehouses
                        ./secure/create_snowflake_objects.py -s schemas
                        export DBT_SNOWFLAKE_ROLE=${PREV_DBT_SNOWFLAKE_ROLE}

                        cd $DBT_HOME
                        export DBT_DATABASE=JENKINS_DW_DATABASE_"$CHANGE_ID"
                        
                        dbt --no-write-json run-operation create_db --args "{db_name: $DBT_DATABASE}"

                        dbt --no-write-json run-operation manage_masking_policies
                    '''
                    sh label: "Run dbt build", script: '''
                        # Run dbt build *****
                        cd $DBT_HOME
                        # This will set a variable MANIFEST_FOUND = to 0 if there is no current manifest in prod for this version
                        ../automate/dbt/get_artifacts.sh
                        export MANIFEST_FOUND=$(cat temp_MANIFEST_FOUND.txt)
                        if [ $MANIFEST_FOUND -eq 1 ]
                        then
                          dbt build --fail-fast --defer --state logs --select state:modified+
                        else
                          echo "No manifest found for current version of dbt, doing a full dbt build"
                          dbt build --fail-fast
                        fi

                        pre-commit run --from-ref origin/main --to-ref HEAD

                        cd $PROJECT_HOME
                        PREV_DBT_SNOWFLAKE_ROLE=${DBT_SNOWFLAKE_ROLE}
                        export DBT_SNOWFLAKE_ROLE='JENKINS_DBT_RUNNER'
                        ./secure/create_snowflake_objects.py -s roles
                        export DBT_SNOWFLAKE_ROLE=${PREV_DBT_SNOWFLAKE_ROLE}
                    '''
                    sh label: "Grant access to PR database", script: '''
                        # Grant access to PR database *****
                        cd $DBT_HOME
                        dbt --no-write-json run-operation grant_uat_permissions --args "{db_name: $DBT_DATABASE}"
                        # TODO: DELETE PR DB IN CASE ABOVE CMD FAILS
                    '''
                }
            }
            post {
                failure {
                    script {
                        // Send email to notify of the error
                        sh '''
                            sendmail ${EMAIL_RECIPIENTS} -t <<EOF
                            Subject: [Jenkins] DBT Feature to Release Tests Failed - ${EMAIL_SUBJECT}
                            EOF
                        '''
                    }
                }
            }
        }

        // Release -> Main step
        stage('Release to Prod Tests') {
            //when { changeRequest target: "main" }
            when { equals(actual: 1, expected: 1) }
            steps {
                withCredentials([usernamePassword(credentialsId: "${SNOWFLAKE_CREDENTIALS_ID}", passwordVariable: 'DBT_PASSWORD', usernameVariable: 'DBT_USER')]) {
                    sh label: "Install dbt packages", script: '''
                        # Install dbt packages *****
                        cd $DBT_HOME
                        dbt deps
                    '''
                    sh label: "Create release database", script: '''
                        # Create release database *****
                        export DBT_DATABASE=JENKINS_DW_DATABASE_"$CHANGE_ID"
                   
                        dbt --no-write-json run-operation create_db --args "{db_name: $DBT_DATABASE}"

                        dbt --no-write-json run-operation manage_masking_policies
                    '''
                    sh label: "Run dbt build", script: '''
                        # Run dbt build *****
                        cd $DBT_HOME
                        # This will set a variable MANIFEST_FOUND = to 0 if there is no current manifest in prod for this version
                        ../automate/dbt/get_artifacts.sh
                        export MANIFEST_FOUND=$(cat temp_MANIFEST_FOUND.txt)
                        if [ $MANIFEST_FOUND -eq 1 ]
                        then
                          dbt build --fail-fast --defer --state logs --select state:modified+
                        else
                          echo "No manifest found for current version of dbt, doing a full dbt build"
                          dbt build --fail-fast
                        fi
                    '''
                    sh label: "Grant access to release database", script: '''
                        # Grant access to release database *****
                        dbt --no-write-json run-operation grant_uat_permissions --args "{db_name: $DBT_DATABASE}"
                    '''
                }
            }
            post {
                failure {
                    script {
                        // Send email to notify of the error
                        sh '''
                            sendmail ${EMAIL_RECIPIENTS} -t <<EOF
                            Subject: [Jenkins] Release to Prod Tests Tests Failed - ${EMAIL_SUBJECT}
                            EOF
                        '''
                    }
                }
            }
        }

        // CD Step

        stage('Merge to Main, deploy to production') {
            when {
                expression { !env.CHANGE_ID && env.BRANCH_NAME == "main" }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: "${SNOWFLAKE_CREDENTIALS_ID}", passwordVariable: 'DBT_PASSWORD', usernameVariable: 'DBT_USER')]) {
                    sh label: "Install dbt packages", script: '''
                        # Install dbt packages *****
                        export DBT_DATABASE=PROD_DW_DATABASE
                        echo $DBT_DATABASE
                                                
                        cd $DBT_HOME

                        dbt deps
                    '''
                    sh label: "Deploy", script: '''
                        # Deploy *****
                        dbt --no-write-json run-operation manage_masking_policies

                        # Run only changed models
                        ../automate/dbt/get_artifacts.sh
                        export MANIFEST_FOUND=$(cat temp_MANIFEST_FOUND.txt)

                        ../automate/blue_green_run.py --deployment-run
                    '''
                    sh label: "Clean up", script: '''
                        # Clean up *****
                        ../automate/dbt/remove_test_databases.sh
                    '''
                    sh label: "Generate dbt docs", script: '''
                        # Generate dbt docs *****
                        # Generate docs to upload in the next step
                        dbt docs generate
                    '''
                }
                withCredentials([usernamePassword(credentialsId: 'sourcecode-bitbucket', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USER')]) {
                    sh label: "Update dbt docs", script: '''
                        # Update dbt docs *****
                        rm .pre-commit-config.yaml
                        automate/dbt/update_dbt_docs.sh
                    '''
                }
            }
            post {
                failure {
                    script {
                        // Send email to notify of the error
                        sh '''
                            sendmail ${EMAIL_RECIPIENTS} -t <<EOF
                            Subject: [Jenkins] Merge to Main, deploy to production Failed - ${EMAIL_SUBJECT}
                            EOF
                        '''
                    }
                }
            }
        }
    }
}
