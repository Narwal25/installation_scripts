#!/bin/bash

# Function to display the menu
display_menu() {
    echo "Select which system to install:"
    echo "1. Magento"
    echo "2. Krayin"
    echo "3. Unopim"
    echo "4. Bagisto"
    echo "5. Exit"
    read -rp "Enter your choice: " choice
}

# Function to install Magento
install_magento() {
    echo "Installing Magento..."
    ./magento.sh  
}

# Function to install Krayin
install_krayin() {
    echo "Installing Krayin..."
    ./krayin.sh 
}

# Function to install Unopim
install_unopim() {
    echo "Installing Unopim..."
    ./unopim.sh 
}

# Function to install Bagisto
install_bagisto() {
    echo "Installing Bagisto..."
    ./bagisto.sh
}

# Main function to control the flow of the script
main() {
    while true; do
        display_menu
        case $choice in
            1) install_magento ;;
            2) install_krayin ;;
            3) install_unopim ;;
            4) install_bagisto ;;
            5) echo "Exiting..."; break ;;
            *) echo "Invalid choice, please try again." ;;
        esac
    done
}

main
