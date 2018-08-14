# phad
Pi-hole Alternative Display

### Quick Introduction

While Pi-hole's chronometer is nice and other text/console displays are better, I still feel there was the potential for even more. Many of the displays that run chronometer, etc. are LCD touchscreens, yet the "touch" part isn't used. I also like having the ability to customize my Pi-hole display, so using templates for creating the display rather than hardcoding the display into a script also makes sense to me. phad combines support for touchscreens with python templates to let you display multiple screens of data by simply tapping on the screen. If you don't have a touchscreen then you can still have phad cycle between different screens at a rate you determine.

phad's default screens include:

##### main page

![main page image](https://raw.githubusercontent.com/bpennypacker/images/master/phad/main.png)

##### top ads page

![top ads image](https://raw.githubusercontent.com/bpennypacker/images/master/phad/top_ads.png)

##### top domains page

![top domains image](https://raw.githubusercontent.com/bpennypacker/images/master/phad/top_domains.png)

##### top clients page

![top clients image](https://raw.githubusercontent.com/bpennypacker/images/master/phad/top_clients.png)


### Quick Installation
These instructions assume you already have a Raspberry Pi configured with Pi-hole and a touchscreen display. As there are many options for hardware and software, any initial setup and configuration is beyond the scope of these instructions. 

1. Clone this repo using `git` or download and uncompress a release from the [releases page on GitHub](https://github.com/bpennypacker/phad/releases).
2. Install any missing python dependencies by invoking `pip install -r requirements.txt`
3. Add the phad command to `~/.bashrc`:
```
if [ "$TERM" == "linux" ] ; then
    while :
        do
        # Run phad in touchscreen mode (the default)
        /home/pi/git/phad/phad
    
        # If you don't have a touchscreen or just want to cycle between screens every 10 seconds
        # then use this command instead:
        # /home/pi/git/phad/phad -s 10
    done
fi
```
4. reboot your pi

Once your pi has rebooted it should display phad's main screen on your pi's display. Simply tap the touchscreen to cycle to other displays (or wait 10 seconds for the display to automatically cycle if you specified `-s 10`). The default phad configuration will show a summary page followed by pages that show the top ads, domains, and clients. 

By default (when `-s` is not specified) phad will revert back to the main summary page after 10 seconds. (The length of timeout can easily be changed or disabled via the phad.conf file.)

### Configuration

phad reads the configuration file phad.conf that is located in the same directory as phad itself. This configuration file allows you to modify the appearance of variables used to render the phad screens and modify the behavior of phad itself. See the detailed comments in phad.conf for explainations of the various options.

All variable formatting that is configurable via phad.conf is based on the "new style" of python formatting that can be found at https://pyformat.info

The templates used to display each phad screen are located in the `templates` directory. These templates are standard Jinja2 templates. Jinja2 is a full featured template engine for Python, and its documentation can be found at http://jinja.pocoo.org/docs/templates/

Both Python variable formatting and Jinja2 templating are well beyond the scope of this README. Please refer to the above two project pages for detailed documnentation on both.

### Command Line Options

Invoking `phad --help` will display a summary of command line options. Options are outlined below as well with a bit more detail.

* -c [--config] configfile
 
   Load an alternate configuration file. By default phad will load the phad.conf that is found in the same directory as phad itself.

* -s [--seconds] delay

   Run phad in "slideshow" mode, cycling through each screen on the display by ***delay*** seconds.
   

* -t [--template] template_name

   Render the specified template and print it to stdout. This is handy when debugging/testing custom templates, etc.
   
* -r [--readconf]

   When phad is invoked normally it will write it's process ID (PID) to a file specified in the phad.conf file. The ***--readconf*** option will send a signal to that process telling it to re-read the configuration file. This lets you SSH into a pi-hole server and make changes to the configuration of phad without having to reboot or do any other tricks to get it to start using the new configuration.
   
* -j [--json]

   Dump all phad variables to stdout in a JSON structure. This lets you view all the variables that are available within the phad templates.
   
* -i [--items]

   Dump  a list of all the top-level variable names used by phad. Phad breaks down variables into logical groups, such as *top_ads*, *top_domains*, *host* (for host-specific data), *version* (for the version of pi-hole, it's components, etc) and so on. 
   
* -l [--list] item [item...[

   Use `--list` along wtih `--json` to limit the JSON that is displayed by specifying one or more of the item names in the `--items` output. For example, use `--json --list top_ads` to see only the variable data associated with the top_ads set of data.
   
* -d [--debug]

   Generate debugging output to stdout
   
### Tips and Tricks

* To blank your touchscreen by default, edit the `templates` option in `phad.conf` and add the template `blank.j2` to the beginning of the list, then restart phad or tell it to re-read the configuration file via `./phad -r`. The `blank.j2` template simply clears the screen and does not print anything else.

* To see a list of all the clients on your network that your pi-hole knows about and their hostnames if pi-hole knows about them as well, run `./pihole -t clients.j2`. The clients.j2 template simply dumps a list of all known client IP addresses and hostnames if known.

* Template files are read in each time phad cycles to display a new template. If you are editing an existing template or creating a new one that you have already added to the `templates` option in `phad.conf` then simply tapping on your display to cycle through the templates is enough for phad to re-load it and display any changes that you have made.
