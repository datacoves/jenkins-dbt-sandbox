# Jenkins dbt Sandbox

# Introduction

This repo contains a simple environment for hosting Jenkins locally in Docker
on a development machine. Using this environment, you can create and test a
dbt `Jenkinsfile` pipeline without requiring:

- External git repository (Simply commit your changes locally and click "Build now" in Jenkins)
- Jenkins server (Runs locally instead)
- Data warehouse (dbt and other commands use simple scripts that mock dbt and other commands)
- Email server (Uses a mock `sendmail` script to simulate sending build failure emails)

# Detailed Setup Instructions

- Build/start container

    -   `docker compose build`
    -   `docker compose up -d`
    -   `docker compose exec jenkins bash`

-   For Mac: Mac: Configure to allow SSH connections: <https://support.apple.com/lt-lt/guide/mac-help/mchlp1066/mac>

    -   Enable "Remote login"
    -   Only these users: Add your own username to this list

-   Initial SSH setup (Run this in Docker bash from above)

    -   `ssh-keygen`, then hit "Return" three times
    -   Copy the key to your host computer. You'll have to enter your host password.

        -   Mac: `ssh-copy-id YOUR_HOST_USER_NAME@docker.for.mac.localhost`
        -   Linux: `ssh-copy-id YOUR_HOST_USER_NAME@localhost`

    -   Verify you can log into the host

        -   Mac: `ssh YOUR_HOST_USER_NAME@docker.for.mac.localhost`
        -   Linux: `ssh YOUR_HOST_USER_NAME@localhost`

-   Initial core Jenkins setup

    -   <http://localhost:8080>
    -   In the Docker bash session, type: `cat /var/jenkins_home/secrets/initialAdminPassword`
    -   Copy-paste the output into the browser "Administrator password" field
    -   Click "Install suggested plugins". This should include:

        -   Pipeline
        -   Matrix Authorization Strategy

    -   In the "Create First Admin User" screen, click the "Skip and continue as admin" link.
    -   In the "Instance Configuration" screen, click "Save and Finish" (i.e. accept the default for "Jenkins URL").
    -   Click "Start using Jenkins".

-   Add more plugins

    -   Click "Manage Jenkins"
    -   Click "Manage Plugins"
    -   Click "Available"
    -   Type "blue ocean" in the search field.
    -   Click the checkbox for the "Blue Ocean" plugin (should be top of the list).
    -   Click "Install without restart".
    -   When installation completes, click "Go back to the top page".

-   Set up git user. Go to <http://localhost:8080/securityRealm/addUser> to add a user.

    -   user: `git`
    -   password: `login`
    -   Full name: `git user`
    -   E-mail address: Enter any email address
    -   Click "Create User"

-   Set up Jenkins permissions. Go to <http://localhost:8080/configureSecurity/>.

    -   Select "Jenkins' own user database" as the Security Realm. (This is the default.)
    -   Select "Matrix-based security" in the Authorization section
    -   A permission table will appear. On the far right of the "Authenticated Users" row, click on the checkbox that says "Grant all permissions to authenticated".
    -   Set up permissions for the "git" user. Click on "Add user", type "git", and click OK. A new row appears, titled "git user". Check the following boxes:

        -   Overall/Read
        -   Job/Build
        -   Job/Discover
        -   Job/Read

    -   Click "Save" to accept the new permissions.

  -   Create a Jenkins build pipeline.

      -   Click on "New Item" in the Jenkins menu
      -   In the "Enter an item name" field, enter the build job name (e.g. "pipeline").
      -   Click "Pipeline"
      -   Click "OK"
      -   Configure the build pipeline

          -   Under Pipeline / Definition, select "Pipeline script from SCM"
          -   In the "SCM" dropdown, select "git".
          -   In the "Repository URL" field, enter (you'll need to change the host user name and PROJECT_DIR based on where the repo with Jenkinsfile is located on the host)

              -   Mac: `YOUR_HOST_USER_NAME@docker.for.mac.localhost:PROJECT_DIR/.git`
              -   Linux: `YOUR_HOST_USER_NAME@localhost:PROJECT_DIR/.git`

          -   If your Jenkinsfile requires credentials, configure them under the section titled "Credentials" by clicking "Add" and selecting "Jenkins". Jenkins supports many kinds of credentials, but the most commonly used is "Username with password". If that's what you need, select it and fill out the "Username", "Password", and "ID" fields. The ID must match the credentialsId specified in the Jenkinsfile withCredentials() call. When you've filled out those fields, click "Add".
          -   In the Script Path field, accept the default (`Jenkinsfile`)
          -   Under "Branches to build", "Branch Specifier (blank for 'any')", enter the name of the branch you want to build, e.g. "main". If the branch name doesn't exist in the repo, builds will fail with a somewhat confusing error (see below).
          - Click "Save"

 
                 hudson.plugins.git.GitException: Command "git fetch --tags --force --progress --prune -- origin +refs/heads/master:refs/remotes/origin/master" returned status code 128:
                 stdout:
                 stderr: fatal: couldn't find remote ref refs/heads/master
                 fatal: the remote end hung up unexpectedly


-   If necessary, add credentials for the build.
-   Run the Jenkins build pipeline

    -   Click "Build Now"
    -   A numbered build will appear below. Right-click on the link, e.g. "#1" and select "Open link in new tab".
    -   In the new tab that opens, click on "Console output". You'll see the results of the build.

-   Iterating on the build job...

    -   You can make changes to the repo on the host, then commit those changes and click "Build Now" to run another build. You don't need to "git push", because Jenkins is pulling the code directly from the host.
    -   You can make changes to the Build Pipeline by clicking "Configure". This will display the same screen you used earlier when creating the build pipeline.
    -   To view the nicer "Blue Ocean" pipeline output, go to <http://localhost:8080/blue>, then click on your build pipeline.