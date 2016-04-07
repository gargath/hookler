Hookler
============================

A collection of push-to-deploy git hooks and related scripts

## Goals
The aim of this project is to provide a universal mechanism to deploy web applications.
It provides a set of Git hooks that can be used in a remote repository to react to a 'git push' by deploying the pushed code
(after a sanity check).

This avoids error-prone manual steps to deploy a new version of a tool and allows a developer to concentrate on the code she is
working on rather than the hosting environment.


## General Design
Currently the main logic is contained in pre-receive and post-receive hooks designed to reside in a bare clone of the origin repository on the deployment target.

**pre-receive**  
On a git push, this hook will perform a general sanity check on the pushed commit(s), enforcing the following rules:

- Only a single ref is being pushed.
- The pushed ref is a tag (not a HEAD).
- The tag name begins with either "release-" or "staging-".

If any of these conditions are not met, the push is rejected.


**post-receive**
Once the commit has been accepted, this hook will perform the following steps:

- Read the target directories for production and staging environments from the config file (*config.yaml*)
- Check out the code for the received revision to a temporary directory

If the push is adding a tag:

- It will run a rake 'depoy' task on the checked out revision (*see below*). Any application specific deployment tasks  
(such as running compilers, syntax checks or creating symlinks) should be defined in the application's rakefile)
- Finally it creates a symlink to the "latest" and "previous" releases.

If the push deletes a tag:

- It will attempt to roll back that release
- It checks whether the deleted tag corresponds to the latest release (only this can be automatically rolled back)
- It will then again check out the code for that revision and execute the take 'rollback' task, allowing for the execution of application specific cleanup
- If this succeeds, latest and previous symlinks are changed to point to previous and previous-1 respectively


A sample `.htaccess` file is included which will redirect any request for /webapp or /webapp/some_resource
to /webapp/latest or webapp/latest/some_resource respectively.


## The application's rakefile

In order to keep this mechanism generic and not specific to each application, applications should supply a rakefile to execute any deployment or rollback
logic that they require.
This rakefile must contain at least two tasks:

**deploy**
This task is executed in the root of the checked-out Git working tree on deployment and will receive the following arguments:

```ruby
# source_dir is the temporary directory containing the checked-out revision
# target_dir is the destination directory as determined by config.yaml and the tag name (release or staging)
# release_folder is the folder name to be created for this release, normally the SHA of the commit
task :deploy, [:source_dir, :target_dir, :release_folder]
```

The hook assumes that after rake successfully finishes this task, there will be a folder named `:release_folder` underneath `:target_dir`
It will then place symlinks latest and previous accordingly.

**rollback**
On rollback, the rakefile's rollback task is executed thus:

```ruby
# target_dir is the destination directory as determined by config.yaml and the tag name (release or staging)
# release_folder is the folder name to be created for this release, normally the SHA of the commit
task :rollback, [:target_dir, :release_folder]
```

The hook expects the rake task to deal with any application specific cleanup, including deleting `:release_folder`, if desired.
It will then replace symlinks latest and previous to point to the previous two releases.


## Slack Integration

The hooks have Slack capability. Simply add a valid Slack inbound webhook to the config file


## Usage Instructions

In order to use these hooks, you will need to do the following:

* Add a rakefile to your application that includes the above mentioned tasks
* Provide all developers SSH access to the deployment environment
* Clone a bare copy of the application repository you want to enable for push-to-deploy:  
```bash
$ git clone --bare my_project my_project.git
```
* Copy pre-receive, post-receive and config.yaml to the bare clone's `/hooks` directory
* (optional) Modify the included .htaccess by replacing the path name on the web server
to match your path structure
* (optional) Copy the modified .htaccess file to the root of the deployment directory (so that it will
sit alongside the individual version folders)
* (optional) Add webhook URL to config file if you want Slack integration


## Requirements

* The hooks are written in ruby and thus require ruby version 2.2.0 or higher.
* Rake Gem
* FileUtils Gem
* RestClient Gem
* A filesystem that supports symlinks
* Apache with per-application .htaccess enabled
* mod_rewrite
*
