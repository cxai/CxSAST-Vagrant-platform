# A CxSAST Vagrant Virtual Machine platform
A Vagrant managed Virtual Box VM template for quickly deploying a Checkmarx all-in-one plaftorm.

## Prerequisites and setup
* Make sure you have Vagrant and VirtualBox installed
* Clone this repository
* Copy CxSetup.exe and license.cxl to the same folder
* Run `vagrant up`

## Notes

* The first time vagrant creates the VM it will pull the required `alexivkin/windows_2016` box from the vagrant cloud which is around 7Gb.
Packer source for this box is [here](https://github.com/alexivkin/windows_2016). You can use any other standard windows 2016 server box as the base,
but mine is slimmed down and heavily optimized.

* All pre-configured users/passwords are set to admin/admin
* Base memory in vagrantfile is set to 4Gb. You might want to increase it
* Tested on Checkmarx 8.6 and 8.7
