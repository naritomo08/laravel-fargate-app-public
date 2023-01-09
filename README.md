# laravel-fargate-app-public

ECR/ECSを立ち上げるためのアプリ部分になります。

## 構築環境

GitHubActionを動かす、アプリ環境になります。
mainブランチが更新されるとビルド/デプロイが動きます。

### Container structure

```bash
├── app
├── web
├── db
└── cache
```

#### app container

- Base image
  - [php](https://hub.docker.com/_/php):8.0-fpm-buster
  - [composer](https://hub.docker.com/_/composer):2.0

#### web container

- Base image
  - [nginx](https://hub.docker.com/_/nginx):1.20-alpine
  - [node](https://hub.docker.com/_/node):16-alpine

#### db container

- Base image
  - [mysql](https://hub.docker.com/_/mysql):8.0

#### cache container

- Base image
  - [redis](https://hub.docker.com/_/redis):6.2.4-alpine

## 参照書籍/サイト

[TerraformでFargateを構築してGitHub Actionsでデプロイ！Laravel編](https://www.amazon.co.jp/gp/product/B09GFB67X1/ref=ppx_yo_dt_b_d_asin_title_o00?ie=UTF8&psc=1)

[Docker Desktop インストール手順](https://qiita.com/R_R/items/a09fab09ce9fa9e905c5)

[UbuntuでAWS CLIを使えるようにする](https://qiita.com/SSMU3/items/ce6e291a653f76ddcf79)

[nodejs、npm の最新版をインストールする（Ubuntu）](https://www.softel.co.jp/blogs/tech/archives/6487)

[ECSインフラ構築](https://github.com/naritomo08/laravel-fargate-infra-public)

## 事前作業

ECSインフラ構築が完了していること。

[ECSインフラ構築](https://github.com/naritomo08/laravel-fargate-infra)

以下のコマンドを利用できている状態になっていること。

```bash
docker-compose

aws

npm
```

## 利用方法

### ソースを入手する。

以下のgitコマンドで入手する。

```bash
git clone https://github.com/naritomo08/laravel-fargate-app-public.git laravel-fargate-app
cd laravel-fargate-app
rm -rf .git
```

### ローカルdocker立ち上げ

```bash
docker-compose build --no-cache --force-rm
docker-compose up -d
```

### .envファイルコピー

```bash
cd backend
cp .env.example .env
```

### Laravelコマンド実施

```bash
docker-compose exec app composer install -n --prefer-dist --no-dev
docker-compose exec app php artisan key:generate
docker-compose exec app php artisan storage:link
docker-compose exec app chmod -R 777 storage bootstrap/cache
```

### 権限設定

```bash
cd ..
sudo chown -R $USER:$USER backend
sudo chgrp -R www-data backend/storage backend/bootstrap/cache
sudo chmod -R ug+rwx backend/storage backend/bootstrap/cache
```

### npmコマンド実施

```bash
cd backend
npm ci
npm run prod
```

### ローカルでのサイト確認

http://localhost

### ソースのGit登録

githubでの新規リポジトリを作成していること。

以下のコマンドを入力してソースをgithubに登録する。

[name]は自身のユーザ名,[email]は自身のメールアドレスを入れる。

```bash
cd ..
git init
git config --local user.name [name]
git config --local user.email [email]
git add .
git commit -m "first commit"
git branch -M main
git remote add origin <作成したリポジトリパス>
git push -u origin main
```

### .env.prodファイルを更新する。

```bash
vi backend/.env.prod

ファイル内容
---------------------

APP_URL=https://<外向けドメイン名>

ドメイン名を編集すること。
---------------------
```

### デプロイ設定実施

デプロイ実施ファイルを編集する。

```bash
cd .github/workflows
mv deploy.yml.org deploy.yml
vi deploy.yml
```

修正箇所
```bash
run: aws s3 cp .env.$ENV_NAME s3://terraform-state-$SYSTEM_NAME-$ENV_NAME-$SERVICE_NAME-env-file/$IMAGE_TAG/.env
→"terraform-state"のS3バケット名を編集する。
```

デプロイ設定ファイルも更新する。

```bash
cd ../../ecspresso
vi config_prod.yml
```

修正箇所
```bash
url: s3://terraform-state/example/prod/cicd/app_foobar_v1.0.0.tfstate
→"terraform-state"のS3バケット名を編集する。
```

### GitHubへのAWS ID登録

作業実施する前に以下の値を控える。
AWS IAMユーザ一覧から、example-prod-foobar-githubユーザの
アクセスキーを新規作成し、
アクセスキー/シークレットアクセスキーを控える。

GitHubリポジトリページに入り、Settings→secrets→Actionより、
以下の値を追加する。

```bash
名前:
PROD_AWS_ACCESS_KEY_ID
→控えたアクセスキーを入れる。
PROD_AWS_SECRET_ACCESS_KEY
→控えたシークレットアクセスキーを入れる。
PROD_AWS_ASSUME_ROLE_ARN
→arn:aws:iam::[AWSアカウントID]:role/example-prod-foobar-deployer
```
#### SystemsManagerでのLaravel APP_KEY登録

laravel-fargate-appフォルダで以下のコマンドで入力して出力結果を控える。

```bash
docker-compose up -d
docket-compose exec app php artisan key:generate --show
→出てくるコマンド結果を全て控える
```

AWS SystemsManagerに入り、パラメータストアにて
以下の値を登録する。

```bash
名前:
/example/prod/foobar/APP_KEY
値:
先程控えた出力結果を控える。
```

利用枠は標準とする。
タイプは安全な文字列とする。
KMSキーソースは現在のアカウントとする。
KMSキーIDは「alias/aws/ssm」とする。

### GitHubAction実施

mainブランチへのコミット/プッシュを実施して、正常にGitHubActionが稼働することを確認する。

コミットするものがない場合、以下のコマンドで実施が可能。

```bash
git commit --allow-empty -m "empty commit"
git push
```

失敗した場合は、何回かジョブ再実施してみて、同じところで失敗する場合、
構築している手順に漏れが無いか確認すること。

以降はmainブランチ更新で自動的にデプロイされる。

### ECSサイト確認

https://<外向けドメイン名>

## ECSタスク数変更方法

標準ではタスク数が1つしか立ち上がらないが、
以下の方法で増やすことができる。

```bash
cd ecspresso
vi ecs-task-def.json

変更箇所:

"capacityProviderStrategy": [
    {
      "base": 0,
      "capacityProvider": "FARGATE_SPOT",
      "weight": 1
    }


→"weight"の数字を変更する。
```

mainブランチにコミットしてタスクを更新後、
ECSのタスク数が変更されることを確認する。

## 別ソースから本環境に入れてのECS立ち上げ

今回の環境ではlaravel8で稼働することを確認しています。

以下の手順で別途立ち上げているLaravelソースを立ち上げることができます。

### mainソースから別ブランチを作る。

ブランチ名はsitetestにしておく。

### backendフォルダを削除する。

```bash
sudo rm -rf backend
```

### backendフォルダでgit cloneを実施する。

```bash
git clone <gitソースURL> backend
cd backend
rm -rf .git
```

### .env.prodファイルを作成する。

```bash
vi backend/.env.prod

ファイル内容
---------------------
APP_NAME=foobar
APP_ENV=production
# APP_KEY=parameter_store
APP_DEBUG=false
APP_URL=https://<外向けドメイン名>←編集すること。

LOG_CHANNEL=stderr
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=db.foobar.internal
DB_PORT=3306
DB_DATABASE=foobar
DB_USERNAME=foobar
# DB_PASSWORD=parameter_store

SESSION_DRIVER=redis
SESSION_LIFETIME=120

REDIS_HOST=cache.foobar.internal
REDIS_PASSWORD=null
REDIS_PORT=6379
---------------------
```

### deploy.shファイルを作成する。

```bash
cd backend
mkdir scripts
vi deploy.sh

ファイル内容
---------------------
#!/bin/bash

set -eu

php artisan config:cache

php-fpm
---------------------

chmod +x deploy.sh
```

### ローカル立ち上げ直し

```bash
docker-compose build --no-cache --force-rm
docker-compose up -d
```

### .envファイル作成

```bash
cd backend
cp .env.example .env
```

### Laravelコマンド実施

```bash
docker-compose exec app composer install -n --prefer-dist --no-dev
docker-compose exec app php artisan key:generate
docker-compose exec app php artisan storage:link
docker-compose exec app chmod -R 777 storage bootstrap/cache
```

### 権限設定

```bash
sudo chown -R $USER:$USER backend
sudo chgrp -R www-data backend/storage backend/bootstrap/cache
sudo chmod -R ug+rwx backend/storage backend/bootstrap/cache
```

### npmコマンド実施

```bash
cd backend
npm ci
npm run prod
```

### httpsアクセス許可

```bash
cd backend/app/Http/Middleware
vi TrustProxies.php

protected $proxies;
protected $proxies = "*";
→上記を下記に修正する。
```

### ローカルでのサイト確認

http://localhost

### デプロイ設定実施

```bash
cd .github/workflows
vi deploy.yml
```

修正箇所
```bash
on:
  push:
    branches:
      - main
      - sitetest ←追記する

  if: github.ref == 'refs/heads/prod'
  if: github.ref == 'refs/heads/sitetest'
  →2箇所ある上記記載について、上から下に修正する。
```

編集後”sitetest"へのコミット/プッシュを実施して、
正常にGitHubActionが稼働することを確認する。

### ECSサイト確認

https://<外向けドメイン名>

## 環境の消し方

### デプロイ設定実施

```bash
cd .github/workflows
mv deploy.yml deploy.yml.org
```

コミット・デプロイを実施してActionが稼働しないことを確認する。

### docker環境の削除を実施する。

```bash
docker-compose down
```

### 作業フォルダ削除する。

```bash
sudo rm -rf laravel-fargate-app
```

### インフラ側の削除を実施する。

[ECSインフラ構築](https://github.com/naritomo08/laravel-fargate-infra)

### GitHubへのAWS情報登録解除
GitHubリポジトリページに入り、Settings→secrets→Actionより、
以下の値を削除する。

```bash
名前:
PROD_AWS_ACCESS_KEY_ID
PROD_AWS_SECRET_ACCESS_KEY
PROD_AWS_ASSUME_ROLE_ARN
```
### SystemsManagerでのLaravel APP_KEY/DB_PASS削除

AWS SystemsManagerに入り、パラメータストアにて
以下の値を削除する。

```bash
名前:
/example/prod/foobar/APP_KEY
/example/prod/foobar/DB_PASS
```
