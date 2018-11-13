#!/bin/bash
#
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

USERNAME=$1

if [ "${USERNAME}" == "" ]; then
  echo "Please provide a SVN username."
  echo -e "\nUsage:\n\t$0 <username>\n"
  exit 1
fi

read -s -p "Password for SVN user ${USERNAME}: " PASSWORD
echo

SVN_CMD="svn --no-auth-cache --username=${USERNAME} --password=${PASSWORD}"
VERSION=$(cat pom.xml | grep -A1 '<artifactId>tinkerpop</artifactId>' | grep '<version>' | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')

rm -rf target/svn

bin/process-docs.sh || exit 1

# generates javadoc and jsdoc
mvn process-resources -Djavadoc

mkdir -p target/svn
${SVN_CMD} co --depth immediates https://svn.apache.org/repos/asf/tinkerpop/site target/svn

pushd target/svn

${SVN_CMD} update "docs/${VERSION}"
${SVN_CMD} update "javadocs/${VERSION}"
${SVN_CMD} update "jsdocs/${VERSION}"

mkdir -p "docs/${VERSION}"
mkdir -p "javadocs/${VERSION}/core"
mkdir -p "javadocs/${VERSION}/full"
mkdir -p "jsdocs/${VERSION}"

mkdir -p ../jsdocs
rm -rf ../jsdocs/*
cp -R ../../gremlin-javascript/src/main/javascript/gremlin-javascript/doc/ ../jsdocs/

diff -rq -I '^Last updated' docs/${VERSION}/ ../docs/htmlsingle/ | awk -f ../../bin/publish-docs.awk | sed 's/^\(.\) \//\1 /g' > ../publish-docs.docs
diff -rq -I 'Generated by javadoc' -I '^<meta name="date"' javadocs/${VERSION}/ ../site/apidocs/ | awk -f ../../bin/publish-docs.awk | sed 's/^\(.\) \//\1 /g' > ../publish-docs.javadocs
diff -rq -I 'Generated by jsdoc' -I '^<meta name="date"' jsdocs/${VERSION}/ ../jsdocs/doc/ | awk -f ../../bin/publish-docs.awk | sed 's/^\(.\) \//\1 /g' > ../publish-docs.jsdocs

# copy new / modified files
for file in $(cat ../publish-docs.docs | awk '/^[AU]/ {print $2}' | grep -v '.graffle$')
do
  if [ -d "../docs/htmlsingle/${file}" ]; then
    mkdir -p "docs/${VERSION}/${file}" && cp -r "../docs/htmlsingle/${file}"/* "$_"
  else
    mkdir -p "docs/${VERSION}/`dirname ${file}`" && cp "../docs/htmlsingle/${file}" "$_"
  fi
done
for file in $(cat ../publish-docs.javadocs | awk '/^[AU]/ {print $2}')
do
  if [ -d "../site/apidocs/${file}" ]; then
    mkdir -p "javadocs/${VERSION}/${file}" && cp -r "../site/apidocs/${file}"/* "$_"
  else
    mkdir -p "javadocs/${VERSION}/`dirname ${file}`" && cp "../site/apidocs/${file}" "$_"
  fi
done
for file in $(cat ../publish-docs.jsdocs | awk '/^[AU]/ {print $2}')
do
  if [ -d "../jsdocs/doc/${file}" ]; then
    mkdir -p "jsdocs/${VERSION}/${file}" && cp -r "../jsdocs/doc/${file}"/* "$_"
  else
    mkdir -p "jsdocs/${VERSION}/`dirname ${file}`" && cp "../jsdocs/doc/${file}" "$_"
  fi
done

pushd "docs/${VERSION}/"; cat ../../../publish-docs.docs | awk '/^A/ {print $2}' | grep -v '.graffle$' | xargs --no-run-if-empty svn add --parents; popd
pushd "javadocs/${VERSION}/"; cat ../../../publish-docs.javadocs | awk '/^A/ {print $2}' | xargs --no-run-if-empty svn add --parents; popd
pushd "jsdocs/${VERSION}/"; cat ../../../publish-docs.jsdocs | awk '/^A/ {print $2}' | xargs --no-run-if-empty svn add --parents; popd

# delete old files
pushd "docs/${VERSION}/"; cat ../../../publish-docs.docs | awk '/^D/ {print $2}' | xargs --no-run-if-empty svn delete; popd
pushd "javadocs/${VERSION}/"; cat ../../../publish-docs.javadocs | awk '/^D/ {print $2}' | xargs --no-run-if-empty svn delete; popd
pushd "jsdocs/${VERSION}/"; cat ../../../publish-docs.jsdocs | awk '/^D/ {print $2}' | xargs --no-run-if-empty svn delete; popd

CHANGES=$(cat ../publish-docs.*docs | grep -v '.graffle$' | wc -l)

if [ ${CHANGES} -gt 0 ]; then
  ${SVN_CMD} commit -m "Deploy docs for TinkerPop ${VERSION}"
fi

popd
