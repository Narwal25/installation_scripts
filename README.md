# Installation Scripts

This repository contains a set of bash scripts designed to automate the installation of four popular PHP-based platforms: Magento, Krayin, Unopim, and Bagisto. The main script allows you to choose which platform you want to install on your system, making it easy to set up each one in a pre-configured environment.

## Supported Platforms
1. **Magento** - An open-source e-commerce platform.
2. **Krayin** - A self-hosted CRM built on Laravel.
3. **Unopim** - An open-source project management tool.
4. **Bagisto** - A Laravel-based open-source e-commerce platform.

## Features
- Automated installation of necessary utilities like Apache, MySQL, PHP, Composer, and more.
- Custom installation for each platform, including configuration and setup.
- Support for multiple platforms via a single script.
- Configures virtual hosts for each platform with Apache.

## Requirements
- Ubuntu 20.04 or later.
- A user with `sudo` privileges.
- At least 2 GB of RAM and 2 CPU cores (recommended).

## How to Use

1. **Clone the repository**:
    ```bash
    git clone https://github.com/Narwal25/installation_scripts.git
    cd installation_scripts
    ```

2. **Make the `main.sh` script executable**:
    ```bash
    chmod +x main.sh
    ```

3. **Run the script**:
    ```bash
    ./main.sh
    ```

   The script will provide a menu to choose which platform to install. You can choose one of the following:
   - Magento
   - Krayin
   - Unopim
   - Bagisto

   Follow the on-screen prompts to complete the installation.

## Installation Breakdown

Each platform has a dedicated script that automates its installation:

1. **Magento**:
    - Installs Apache2, MySQL, PHP, and other dependencies.
    - Installs and configures Magento from its official GitHub repository.
    - Sets up the database, and configures Magento using the CLI.

2. **Krayin**:
    - Installs Apache2, MySQL, PHP, and other required extensions.
    - Clones the Krayin CRM repository and configures it.
    - Sets up Apache VirtualHost and configures the `.env` file.

3. **Unopim**:
    - Installs Apache2, MySQL, PHP, and other required extensions.
    - Clones the Unopim repository and installs dependencies via Composer.
    - Sets up Apache VirtualHost and configures the `.env` file.

4. **Bagisto**:
    - Installs Apache2, MySQL, PHP, and other required extensions.
    - Clones the Bagisto repository and installs dependencies via Composer.
    - Sets up Apache VirtualHost and configures the `.env` file.

## License

This project is licensed under the [GPL-3.0 License](LICENSE).

## Contributing

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Make your changes and commit them (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

## Acknowledgements

- Thanks to the communities of Magento, Krayin, Unopim, and Bagisto for their great platforms.
- This repository aims to simplify the installation process for developers and system administrators.

## Contact

For questions or support, please open an issue on the [GitHub repository](https://github.com/Narwal25/installation_scripts/issues).
