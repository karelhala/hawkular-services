#!/bin/bash
#
# Copyright 2016 Red Hat, Inc. and/or its affiliates
# and other contributors as indicated by the @author tags.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -xe

if [ "$TRAVIS_PULL_REQUEST" = false ] ; then
    exit
fi

function post_comment {
    set +x
    echo 'Sending comment to github.'
    curl -s -H "Authorization: token $GITHUB_TOKEN"  \
    -i "https://api.github.com/repos/$TRAVIS_REPO_SLUG/issues/$TRAVIS_PULL_REQUEST/comments"  \
    --data  "{\"body\": \"$1\"}" > /dev/null
    set -x
}

# Create docker image.
mvn -s .travis.maven.settings.xml -Pdev,dozip clean install
pushd docker-dist
mvn -s ../.travis.maven.settings.xml docker:build
popd

# Download hawkular-client-ruby and make it ready.
git clone --depth 1 https://github.com/hawkular/hawkular-client-ruby.git
pushd hawkular-client-ruby
bundle install
sed -i "s/  image: .*hawkular-services/  image: \"`whoami`\/hawkular-services/g" docker-compose.yml
docker-compose up -d && ./.travis/wait_for_services.rb && \
sleep 20s

RUN_ON_LIVE_SERVER=1 \
VCR_UPDATE=1 \
SKIP_SSL_WITHOUT_CERTIFICATE_TEST=1 \
SKIP_SECURE_CONTEXT=1 \
SKIP_V8_METRICS=1 \
SKIP_SERVICES_METRICS=1 \
bundle exec rspec && \
post_comment 'This PR seem to be working well with [hawkular-client-ruby](https://github.com/hawkular/hawkular-client-ruby) :+1:.' ||
post_comment 'This PR potentially fails with [hawkular-client-ruby](https://github.com/hawkular/hawkular-client-ruby).'
docker-compose kill
popd
