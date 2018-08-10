#!/system/bin/sh
/system/bin/touch /dev/x
/system/bin/cp -rd --preserve=all /system/etc/ /dev/
/system/bin/sed -i -e 's/secure=1/secure=0/' -e 's/ro.debuggable=0/ro.debuggable=1/' /dev/etc/prop.default
/system/bin/echo '' > /dev/etc/selinux/plat_and_mapping_sepolicy.cil.sha256
/system/bin/echo '(typepermissive adbd)' >> /dev/etc/selinux/plat_sepolicy.cil
/system/bin/echo '(typepermissive shell)' >> /dev/etc/selinux/plat_sepolicy.cil
/system/bin/echo '(typepermissive su)' >> /dev/etc/selinux/plat_sepolicy.cil
/system/bin/mount -o bind  /dev/etc/ /system/etc/
