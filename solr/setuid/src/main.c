// WARNING: This script requires a setuid. It will run as root while being launched as a standard user.

/* NOTE: This program should really be a bash script. Running a "system" call brings some security
         issues in usual conditions. But in the current situation we should be running within
         a docker container and are not concerned with those issues.*/

#include <stdlib.h>
#include <unistd.h>

int main(int argc, char** argv) {

    __uid_t old_uid = getuid();

    // Switch to root.
    // NOTE: This call requires the executable to be owned by root and have the setuid bit enabled.
    setuid(0);

    // Make solr owner of /var/solr.
    system("chown solr /var/solr");

    // Switch back to solr user.
    setuid(old_uid);

    return 0;
}
