# sizer
The "Sizer" is a PowerShell utility that utilizes RoboCopy to quickly find the location of big files.

The original post is located here:

https://www.dhb-scripting.com/Forums/posts/t63-PowerShell-Disk-Sizer

Disk space has always been a problem for the 20 years that I have spent in the IT field, and it doesn't seem to be going away anytime soon.  The crux of the problem is not necessarily the size of the disks;  the operating systems, applications, and user projects just keep getting bigger.  It really only takes one application, one user, or one system log file to run a disk right out of space.  Servers and workstations share the same issue.  Having enough disk space to operate is one of the most important proactive items that an administrator can monitor.  Please see my article on LinkedIn about disk space: https://www.linkedin.com/pulse/full-disk-drives-dustin-higgins

Even if you have a list of machines that are low on disk space, as trivial as it might sound, how does one efficiently locate the big files / directories?

Also, here is a discussion and quick demo: https://www.youtube.com/watch?v=boM_1i_O0qQ

The Sizer utilizes Robocopy.exe to quickly list the size of folders.   With Sizer, you can start at the root of the C:\ drive and quickly drill down to locate problem areas.   There are many posts that illustrate how to list folder sizes with Robocopy.exe.   I give them all credit.  Robocopy.exe is freaking awesome!  Using that method, along with capturing and sizing subfolders is really the key to quickly finding where the disk space is being taken.

There is no more manually checking common problem areas.  Sizer will quickly tell you exactly where the problem areas are, and that equals efficiency.
