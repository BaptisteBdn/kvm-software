# Software kvm switch for libvirt and VFIO users

## Who is this for ?

- You are using a PCI / GPU Passthrough Linux / Windows
- You have 2 GPUs, one for the host, one for the VM
- You use one main monitor that has multiple outputs (connected to the 2 GPUs)
- You want a low latency mouse/keyboard solution for the guest
- Your monitor is i2c-capable! 

You should be able to know if your monitor is i2c-capable by looking at the datasheet or by looking at the monitor on-screen options.

## What does it do ?

This guide is here to help you configure your fully software KVM switch for your setup. You will be able to switch from your host to your guest and from your guest to your host in one shortcut! Passing through your usb devices and switching your monitor input.


## Prerequisite

- [ddcutil](http://www.ddcutil.com/)
- [virtkvm](https://github.com/NeoTheFox/virtkvm)
- [autohotkey](https://www.autohotkey.com/) (if your guest is windows)

## Guide

I am using Arch Linux but it should mostly work the same for other distributions.

Install ddcutil: 
```
sudo pacman -S ddcutil
```

Give the permission required for ddcutil:
- [i2c permissions](http://www.ddcutil.com/i2c_permissions/)
- [kernel module](http://www.ddcutil.com/kernel_module/)

Check the capabilities of your monitor:

```
ddcutil detect
```
You should be able to get the I2C bus number of the monitor: 
```
Display 1
   I2C bus:  /dev/i2c-3
   EDID synopsis:
      Mfg id:               AOC
      Model:                2778X
      Product code:         10104
      Serial number:        XXXXXXXXXXXXXX
      Binary serial number: 665 (0x00000299)
      Manufacture year:     2016,  Week: 12
   VCP version:         2.1
```
Here the I2C number is `i2c-3`, keep it for later.

> If you have something like: 
>```
>   DDC communication failed
>   Is DDC/CI enabled in the monitor's on-screen display?
>```
>Your monitor may not handle I2C well and I suggest you to open an [issue](https://github.com/rockowitz/ddcutil/issues).

Next, get the capabilities with the bus number you just retrieved: 
```
ddcutil --bus 3 capabilities
```
We will only be using the feature 60 in order to switch from one input to another: 
```
   Feature: 60 (Input Source)
      Values:
         01: VGA-1
         03: DVI-1
```
Here I can see 2 inputs out of the 4 that my monitor has (VGA, DVI, HDMI, DP). 
We will be using the values of the inputs to switch them. 
Keep them for later.


>If some inputs are missing you can still try with theses values (They are MCCS standards but they are often not followed):
>```
>1 VGA1
>2 VGA2
>3 DVI1
>4 DVI2
>15 DisplayPort1
>16 DisplayPort2
>17 HDMI1
>18 HDMI2
>```

You now have all the required infos to switch the monitor input. We will now need the usb devices ids.

Get the usb devices ids:
```
lsusb
```
You shoud have something like:
```
Mouse: 046d:c08d 
Keyboard: 28da:1101
```

Next we will use the [virtkvm](https://github.com/NeoTheFox/virtkvm) project.
It will:
- Switch the monitor input with ddcutil
- Attach and Detach the usb devices onto the VM with libvirt
- Listen for HTTP request

While it may not be useful for the host to send a HTTP request in order to use the KVM, it exists so that we can reverse from the guest to the host easily.

To use [virtkvm](https://github.com/NeoTheFox/virtkvm):

```
cd /tmp
git clone https://github.com/NeoTheFox/virtkvm
cd virtkvm
pip install . 
mv example_config.yaml ~/.local/conf/virtkvm/config.yaml
rm -rf /tmp/virtkvm
```
The script should be available in `~/.local/bin`.

You can now change the values of the config.yaml file with your own: 
- libvirt: domain of your VM
- IP address (eth0/enp0s3 or wlan0)
- Enter a new secret
- Change the devices ids
- Change the display bus and the values for the host dans the guest

Example : 
```
kvm:
  usesudo: false
  checkguest: true
libvirt:
  uri: "qemu:///system"
  domain: "win10"
http:
  address: "192.168.1.15:5001"
  security:
    enabled: true
    secret: "xxxxxxxxx"
devices:
  # keyboard
  - vendor: 0x28da
    product: 0x1101
  # mouse
  - vendor: 0x046d
    product: 0xc08d
  # xbox controller
  - vendor: 0x045e
    product: 0x028e
displays:
  # main display
  - bus: 3
    feature: 0x60
    host: 15
    guest: 17
commands:
  guest:
    - echo switch to guest
  host:
    - echo switch to host
```

Try it :
```
~/.local/bin/virtkvm --config ~/.local/conf/virtkvm/config.yaml
```
Start your VM and try switching with a curl request: 
```
curl -X POST -H 'Content-Type: application/json' -H 'X-Secret: xxxxxxxxx' -d '{"to": "guest"}' http://192.168.1.15:5001/switch
```
If it worked, your monitor should have switched to your VM as well as your peripherals.

To automate the process, I created a systemd init file that will be enabled at launch.

Download `virtkvm.service` and replace the user.

Enable and start the service: 
```
systemctl enable virtkvm.service
systemctl start virtkvm.service
```

I am using i3 as my windows manager, therefore I created a bash script and a desktop file to send the HTTP request to switch from the host to the guest.

- Bash script : `switch-to-guest.sh`
- Desktop file : `switch-to-guest.desktop`

Bind to shortcut (I use Win+Shift+/) in i3 config file :

```
bindsym $mod+Shift+slash exec path/to/switch-to-guest.sh
```

Finally, if you are using Windows, you might want to create an AutoHotKey script to bind the HTTP request to a shorcut:
- Download `SwitchToHost.ahk` and update the IP and the secret.
- Move it to the [windows startup folder](https://support.microsoft.com/en-us/windows/add-an-app-to-run-automatically-at-startup-in-windows-10-150da165-dcd9-7230-517b-cf3c295d89dd).
- Run it manually if you don't want to wait for the reboot.
