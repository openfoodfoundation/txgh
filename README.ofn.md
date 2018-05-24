# How the Open Food Network uses txgh

We currently use it on our CI server to automatically commit translations to
the `transifex` branch on Github.

## How to install

We are currently running Ubuntu 16.04.3 LTS.

As root:

```sh
apt install bundler

# Open firewall
ufw allow 9292

# Create unpriviledged user
adduser --disabled-password transifex
```

As transifex user:

```sh
git clone https://github.com/openfoodfoundation/txgh
cd txgh/
git checkout ofn
bundle install --path vendor/bundle

mkdir -p config/secret
echo '
export GITHUB_USERNAME="transifex"
export GITHUB_TOKEN="Github API token of transifex user"
export GITHUB_PUSH_SOURCE_TO="open-food-network"
export GITHUB_BRANCH="transifex"
export GITHUB_WEBHOOK_SECRET=""

export TX_CONFIG_PATH="./config/tx.config"
export TX_USERNAME="transifex@openfoodnetwork.org"
export TX_PASSWORD="Transifex password"
export TX_PUSH_TRANSLATIONS_TO="openfoodfoundation/openfoodnetwork"
export TX_PUSH_TRIGGER_REVIEWED_OR_TRANSLATED="translated"
export TX_WEBHOOK_SECRET=""
' > config/secret/env.sh

# API keys are loaded as environment variables.
. config/secret/env.sh

sh start-server.sh

# Add a cron job to check the server frequently
crontab -e
#   */5 * * * * sh -c "cd /home/transifex/txgh && sh start-server.sh"
```

## Testing

To check if the application is running, you can check for an HTTP 200 response
at `/health_check`.

```sh
curl -v http://foo:bar@0.0.0.0:9292/health_check
```

You can simulate a Transifex webhook event triggering a real commit:

```sh
curl http://0.0.0.0:9292/hooks/transifex -d '{"project": "open-food-network", "translated": "100", "resource": "enyml", "event": "translation_completed", "language": "fr"}'
```