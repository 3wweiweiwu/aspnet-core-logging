# Runs a Docker container hosting the database to be targeted by the integration tests and periodically 
# checks for a given amount of tries whether the database is ready to accept incoming connections by
# polling the health state of this container

Param (
    # Represents the name of the Docker image to use for provisioning the database 
    # to be targeted by the integration tests.
    $DockerImageName,

    # Represents the tag associated with the Docker image to use for provisioning the database 
    # to be targeted by the integration tests.
    $DockerImageTag,

    # Represents the name of the Docker container to check whtether is running.
    $ContainerName,

    # Represents the Docker host port to use when publishing the database port.
    $HostPort,

    # Represents the database port to publish to the Docker host.
    $ContainerPort,

    # Represents the environment variables used when running the Docker container.
    # Example: -e "key1=value1" -e "key2=value2".
    $ContainerEnvironmentVariables,

    # Represents the command Docker will use to check whether the container has entered 
    # the "healthy" state or not
    $HealthCheckCommand,

    # Represents the number of milliseconds to wait before checking again whether 
    # the given container is healthy.
    $HealthCheckIntervalInMilliseconds = 250,

    # The maximum amount of retries before giving up and considering that the given 
    # Docker container is not running.
    $MaxNumberOfTries = 120
)

$ErrorActionPreference = 'Stop'
$healthCheckIntervalInSeconds = $HealthCheckIntervalInMilliseconds / 1000

Write-Output "Pulling Docker image ${DockerImageName}:${DockerImageTag} ..."
# Success stream is redirected to null to ensure the output of the Docker command below is not printed to console
docker image pull ${DockerImageName}:${DockerImageTag} 1>$null
Write-Output "Docker image ${DockerImageName}:${DockerImageTag} has been pulled`n"

Write-Output "Starting Docker container '$ContainerName' ..."
Invoke-Expression -Command "docker container run --name $ContainerName --health-cmd '$HealthCheckCommand' --health-interval ${healthCheckIntervalInSeconds}s --detach --publish ${HostPort}:${ContainerPort} $ContainerEnvironmentVariables ${DockerImageName}:${DockerImageTag}" 1>$null
Write-Output "Docker container '$ContainerName' has been started"

$numberOfTries = 0
$isDatabaseReady = $false

do {
    Start-Sleep -Milliseconds $HealthCheckIntervalInMilliseconds

    $isDatabaseReady = docker inspect $ContainerName --format "{{.State.Health.Status}}" | Select-String -Pattern 'healthy' -SimpleMatch -Quiet

    if ($isDatabaseReady -eq $true) {
        Write-Output "`n`nDatabase running inside container ""$ContainerName"" is ready to accept incoming connections"
        exit 0
    }

    $progressMessage = "`n${numberOfTries}: Container ""$ContainerName"" isn't running yet"

    if ($numberOfTries -lt $maxNumberOfTries - 1) {
        $progressMessage += "; will check again in $HealthCheckIntervalInMilliseconds milliseconds"
    }
        
    Write-Output $progressMessage
    $numberOfTries++
}
until ($numberOfTries -eq $maxNumberOfTries)

# Instruct Azure DevOps to consider the current task as failed.
# See more about logging commands here: https://github.com/microsoft/azure-pipelines-tasks/blob/master/docs/authoring/commands.md.
Write-Output "##vso[task.LogIssue type=error;]Container $ContainerName is still not running after checking for $numberOfTries times; will stop here"
Write-Output "##vso[task.complete result=Failed;]"
exit 1