#!/bin/bash

set -eu

php artisan storage:link
php artisan config:cache

chown -R www-data:www-data /work/backend/storage

php-fpm