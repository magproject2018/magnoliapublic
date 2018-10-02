# magnoliapublic

This project uses vagrant to build a Magnolia CMS public instance vm in VirtualBox which uses Nginx as a reverse proxy for Magnolia's Tomcat, SSL enabled, configured for remote Java debugging, and using MySQL for Magnolia Jackrabbit JCR persistence. When running this and https://github.com/magproject2018/magnoliaauthor, you will have a disposable Magnolia dev environment.

1. Clone this repo
2. Install VirtualBox
3. Install Vagrant
4. From your command line, cd to your cloned repo, and enter

    vagrant up
    
5. When it's finished, you should be able to browse to http://192.168.99.41/ to access Magnolia on your local machine.
