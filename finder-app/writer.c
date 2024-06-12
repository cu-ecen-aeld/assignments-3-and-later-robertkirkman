// writer.c for Assignment 2
// Author: Robert Kirkman

#include <stdio.h>
#include <syslog.h>

#define DEST argv[1]
#define DATA argv[2]

int main(int argc, char *argv[]) {
    openlog("writer", LOG_PID, LOG_USER);
    if (argc != 3) {
        syslog(LOG_ERR, "incorrect number of arguments", DEST);
        printf("usage: %s [writefile] [writestr]\n", argv[0]);
        return 1;
    }

    FILE *file_p = fopen(DEST, "w");
    if (file_p == NULL)
    {
        syslog(LOG_ERR, "failed to open %s", DEST);
        printf("failed to open %s\n", DEST);
        return 1;
    }

    syslog(LOG_DEBUG, "Writing %s to %s", DATA, DEST);
    int ret = fprintf(file_p, "%s", DATA);
    if (ret < 0) {
        syslog(LOG_ERR, "failed to write \"%s\" to %s", DATA, DEST);
        printf("failed to write \"%s\" to %s\n", DATA, DEST);
        return 1;
    }

    closelog();
    return 0;
}