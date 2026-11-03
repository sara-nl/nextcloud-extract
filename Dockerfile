# --- Build stage ------------------------------------------------------------
FROM php:8.2-cli AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y -qq \
    make tar gzip zlib1g-dev libzip-dev curl gnupg \
    zlib1g-dev libzip-dev curl git unzip vim\
    && rm -rf /var/lib/apt/lists/*

# Install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php --version=2.9.0 --install-dir=/usr/local/bin --filename=composer
# Run composer inside the app folder
#RUN COMPOSER_ALLOW_SUPERUSER=1 composer install \
#    --no-interaction \
#    --no-progress \
#    --optimize-autoloader
# ---- FIX ENDS HERE ----

# Continue your other steps
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
RUN apt-get install -y -qq nodejs
#RUN npm install && npm run build
