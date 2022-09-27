
-   <a href="#easydb-" id="toc-easydb-">easydb
    <a href="https://selkamand.github.io/easydb/"><img src="man/figures/logo.png" align="right" height="104"/></a></a>
    -   <a href="#installation" id="toc-installation">Installation</a>
    -   <a href="#connecting-to-a-database"
        id="toc-connecting-to-a-database">Connecting to a database</a>
        -   <a href="#step-1-initialise-config-file"
            id="toc-step-1-initialise-config-file">Step 1: Initialise Config
            File</a>
        -   <a href="#step-2-connect-to-database"
            id="toc-step-2-connect-to-database">Step 2: Connect to Database</a>
        -   <a href="#step-3-disconnect-when-finished"
            id="toc-step-3-disconnect-when-finished">Step 3: Disconnect when
            finished</a>
        -   <a href="#what-to-expect" id="toc-what-to-expect">What to expect</a>
    -   <a href="#quick-start-examples" id="toc-quick-start-examples">Quick
        start (examples)</a>
    -   <a href="#disconnect" id="toc-disconnect">Disconnect</a>
-   <a href="#how-does-easydb-work" id="toc-how-does-easydb-work">How does
    easydb work?</a>

<!-- README.md is generated from README.Rmd. Please edit that file -->

# easydb <a href="https://selkamand.github.io/easydb/"><img src="man/figures/logo.png" align="right" height="104"/></a>

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/easydb)](https://CRAN.R-project.org/package=easydb)
<!-- badges: end -->

The goal of easydb is to simplify the process of connecting to databases
using R

## Installation

Install from CRAN

``` r
install.packages('easydb')
```

You can install the development version of easydb like so:

``` r
# install.packages('remotes')
remotes::install_github('selkamand/easydb')
```

## Connecting to a database

### Step 1: Initialise Config File

We need to store your configuration details in a file somewhere on disk.
You can choose where.

A common practice is to create a hidden file in your home directory.

We’ll create our config file: `~/.easydb`

``` r
easydb_init(config_file = '~/.easydb')
```

This only needs to be done once.

### Step 2: Connect to Database

Connect to databases:

`easydb_connect('database_name', '~/.easydb')`

### Step 3: Disconnect when finished

Disconnect from databases:

`easydb_disconnect(connection)`

### What to expect

The first time you try to connect to a database, you may have to answer
some questions about the database (depending on the database type you’re
connecting to).

Once you’ve setup the configuration, you will not have to re-enter
host/port/creds unless you set the argument `from_scratch = TRUE`. This
argument will delete the existing configuration and credentials for the
given database and prompt you to supply updated information.

## Quick start (examples)

``` r
library(easydb)

# Initialise a config file at '~/.easydb'
easydb_init(config_file = '~/.easydb')

# sqlite
sqlitedb <- system.file(package="easydb", "testdbs/mtcars.sqlite")
sqlite_connection <- easydb_connect(sqlitedb, config_file = '~/.easydb')

# mysql
# Example: connect to the public rfam mysql database
#
# See here for connection configuration: 
# https://docs.rfam.org/en/latest/database.html
rfam_connection <- easydb_connect(dbname = "Rfam", config_file = '~/.easydb')


# postgresql
# Example: Connect to public RNAcentral postgres database
#
# See here for connection configuration: 
# https://rnacentral.org/help/public-database
rna_central_connection <- easydb_connect(dbname = 'pfmegrnargs', config_file = '~/.easydb')


# Don't forget to disconnect from databases when you finish!
easydb_disconnect(sqlite_connection)
easydb_disconnect(rna_central_connection)
easydb_disconnect(rfam_connection)
```

## Disconnect

Once you’ve finished working with a database, its best to disconnect
from the db using `easydb_disconnect(connection_object)`

# How does easydb work?

Database configurations (host, port, driver, etc) are stored in a
configuration file that will be created at a user-specified location (we
recommend `~/.easydb`).

Credentials are stored separately in your operating systems credential
store. This is powered by `keyring`. If you’re on linux you may need to
install the secret service library. See the
[readme](https://github.com/r-lib/keyring) for details
