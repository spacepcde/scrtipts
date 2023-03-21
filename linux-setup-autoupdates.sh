#The script sets up an automatic system update and sends an email notification with the update status. It performs these tasks:
#
#    Sets up variables:
#        CRON_JOB: the cron job schedule for running the update script.
#        EMAIL_TO: the email address to send the update notifications.
#        HOSTNAME: the hostname of the system.
#
#    Defines functions:
#
#        update_system: updates the system package repository and upgrades the packages.
#
#        main: the main function which includes several tasks:
#
#        a. Updates the package repository using the update_system function.
#        b. Installs SSMTP (Simple SMTP) for sending emails.
#        c. Creates an SSMTP configuration file with the specified email and hostname, and copies it to the appropriate directory.
#        d. Sets the permissions for the SSMTP configuration file.
#        e. Creates a /skripte/ directory and an update.sh file inside it. The update.sh file contains the following functions:
#
#
#        i. is_reboot_required: checks if a system reboot is required after the update.
#        ii. send_email: sends an email with the update status and whether a reboot is required.
#        iii. main_update: updates the system, sends an email with the update status, and reboots the system if necessary.
#
#        f. Sets the execute permissions for the update.sh file.
#        g. Adds the cron job entry to the root user's crontab to run the update.sh script every Saturday at 3 a.m.
#
#After the script runs, the system is set up to automatically update and send email notifications about the update status.

#!/bin/bash

# Variablen
CRON_JOB="0 3 * * SAT /bin/bash /skripte/update.sh"
EMAIL_TO=""
HOSTNAME=$(hostname)

# Funktionen

# Update-Funktion
update_system() {
    sudo apt-get update && sudo apt-get upgrade -y
}

# Hauptfunktion
main() {
    # Erstelle den Cronjob-Eintrag

    # Aktualisiere das Paketverzeichnis
    update_system

    # Installiere SSMTP
    sudo apt-get install -y ssmtp

    # Erstelle die SSMTP-Konfigurationsdatei
    cat > ssmtp.conf << EOL
root=$EMAIL_TO
mailhub=
hostname=$HOSTNAME
EOL

    # Kopiere die erstellte SSMTP-Konfigurationsdatei in das erforderliche Verzeichnis
    sudo cp ssmtp.conf /etc/ssmtp/ssmtp.conf

    # Setze die Berechtigungen für die SSMTP-Konfigurationsdatei
    sudo chmod 644 /etc/ssmtp/ssmtp.conf

    echo "SSMTP wurde erfolgreich installiert und konfiguriert."

    # Erstelle den Ordner /skripte/
    sudo mkdir -p /skripte/

    # Erstelle die Datei update.sh
    cat > /skripte/update.sh << 'EOL'

is_reboot_required() {
    if [ -f /var/run/reboot-required ]; then
        return 0
    else
        return 1
    fi
}

# Feedback-E-Mail-Funktion
send_email() {
    local success=$1
    local reboot=$2
    local subject=""
    local message=""

    if [ $success -eq 1 ]; then
        subject="Update erfolgreich - $HOSTNAME"
        message="Die automatischen Updates für $HOSTNAME wurden erfolgreich durchgefuehrt."
		    else
        subject="Update fehlgeschlagen - $HOSTNAME"
        message="Bei den automatischen Updates für $HOSTNAME ist ein Fehler aufgetreten. Bitte überprüfen Sie die Systemprotokolle, um weitere Informationen zu erhalten."
    fi

    if [ $reboot -eq 1 ]; then
        message="$message\n\nEin Neustart des Systems ist erforderlich."
    fi

    # E-Mail senden
    echo -e "Subject: $subject\n\n$message" | ssmtp -v "$EMAIL_TO"
}

# Hauptfunktion für update.sh
main_update() {
    update_system
    if [ $? -eq 0 ]; then
        send_email 1 $(is_reboot_required && echo 1 || echo 0)
        if is_reboot_required; then
            reboot
        fi
    else
        send_email 0 0
    fi
}

main_update
EOL

    # Setze die Ausführungsrechte für die Datei update.sh
    sudo chmod +x /skripte/update.sh

    echo "Der Ordner /skripte/ wurde erstellt und die Datei update.sh hinzugefügt."

    # Füge den Cronjob-Eintrag in die Crontab des Root-Benutzers ein
    echo "$CRON_JOB" | sudo tee -a /etc/crontab > /dev/null

    echo "Der Cronjob wurde erfolgreich erstellt und wird samstags um 3 Uhr morgens ausgeführt."
}

main

