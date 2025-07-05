# Simple Xampp Control

> **Disclaimer:** This project is not affiliated with or endorsed by XAMPP, Apache Friends, or any of their partners. XAMPP is a trademark of Apache Friends. This tool is an independent utility intended solely for educational and administrative convenience.

This tool was developed to allow Xampp to be started in an Active Directory domain environment without administrative privileges, while simultaneously restricting access to the Xampp installation files in `C:\xampp` so that users cannot arbitrarily place files or modify settings.

For this reason, *Simple Xampp Control* is suitable for educational environments where learners work with a preconfigured setup to learn PHP and/or SQL using the MySQL database.  
Changes to the Xampp server that are not made by the administrator are not supported or possible.

**Only Xampp in its minimal installation with Apache and MySQL is supported!**

## Problem

By default, Xampp installs all files into the `C:\xampp` folder.  
This also includes the `htdocs` folder as well as the data folder for the MySQL installation.  
Users should have write access only to these folders and only see their own files.  
However, this restriction creates a few problems, since users then no longer have write permissions (e.g., no write access to their own web files or for Apache to its temp folder at `C:\xampp\tmp`).

## Solution

Symlinks, network drives, and more symlinks :).  
While this may seem strange and messy at first, it turns out to be a clean and effective solution to the problem.

### PrepareXampp.ps1

This script sets up the required folder structure for Xampp, restricts access accordingly, and creates the necessary symlinks.

**This script must be run with administrative privileges.**

#### Usage

```
.\PrepareXampp.ps1 <Drive letter to be used in symlinks, e.g. W (without colon or path)> <Existing drive letter for start script, see #SimpleXamppControl.ps1 in README>
```

#### ACLs

Using predefined SDDL-based ACLs, access to the `C:\xampp` folder is restricted so that only administrators (including domain admins) have write access.  
All other users are limited to read-only access.

A folder structure under `C:\xampp-public` is created for Apache and MySQL temporary files. This structure cannot be changed without administrative rights.  
However, users have write access to the contents of these folders.

#### Symlinks

The folder `mysql\data` is first renamed to `mysql\data-template` so that a symlink can be created at `data` later on, preserving the default Xampp-supplied database (referred to as the template).  
The user-writable folders (`htdocs` and `mysql\data`) are linked to a network drive.  
Simultaneously, the required temporary folders are linked to `C:\xampp-public`.

The symlinks are created as follows:

```
C:\xampp\htdocs               ==> DriveLetter:\Web\htdocs  
C:\xampp\mysql\data           ==> DriveLetter:\Web\mysqldata  
C:\xampp\tmp                  ==> C:\xampp-public\tmp  
C:\xampp\apache\logs          ==> C:\xampp-public\apache-logs  
C:\xampp\phpmyadmin\tmp       ==> C:\xampp-public\phpmyadmin-tmp  
```

#### Network Drives

Since only administrators have access to `C:\xampp`, users cannot change the symlink targets of `htdocs` and `mysql/data` to their own folders at runtime.  
This limitation is addressed by using symlinks to network drives, as the target of a symlink does not need to exist at the time of creation.

The `PrepareXampp.ps1` script therefore creates symlinks to the specified network drive, pointing to `DriveLetter:\Web\htdocs` and `DriveLetter:\Web\mysqldata`.  
With regular user rights, the documents folder can later be mounted to the chosen drive letter.

For example:

The user can create files in `C:\xampp\htdocs`, which are then stored in their personal folder at `\\localhost\C$\Users\Username\Documents\Web\htdocs`.

```
C:\xampp\htdocs  == symlink ==>  W:\Web\htdocs  
W: is mounted to ==>  \\localhost\C$\Users\Username\Documents\
```

#### Result

The user gets individual access to `C:\xampp\htdocs` and `C:\xampp\mysql\data`, while the rest of the `C:\xampp` directory remains read-only.

---

### XamppClassRoomStarter.ps1

The `XamppClassRoomStarter.ps1` script ensures that the network drive is mounted, the MySQL database is copied from the template folder to the user's directory, and Apache and MySQL are then started.

#### Usage

```
.\XamppClassRoomStarter.ps1 -Action <start/reset-database> -UserWebDriveLetter <Drive letter, e.g. W>
```

When run, the script looks for the user’s Documents folder and creates a `Web` subfolder within it.  
Two scenarios are supported:

| Type                  | Network drive target                          |
|-----------------------|-----------------------------------------------|
| Local documents folder | `\\localhost\C$\Users\<Username>\Documents\Web` |
| Folder redirection     | `\\<Path to redirected documents>\Web`         |

In the first case, access to the `C` drive via `\\localhost\C$` must be possible.

If the second parameter is `true`, no mount attempt is made, and the script assumes a preexisting network drive at the given letter (e.g. created via GPO).

In both cases, the following folder structure is created on the root of the drive:

```
W:
├───htdocs
└───mysqldata
```

#### Resetting the Database

If the script is run with `-Action reset-database`, it launches an interactive console prompt asking the user if they really want to reset the database.  
If the user confirms with `yes`, the database in the user's folder is deleted and replaced with a fresh copy of the template.