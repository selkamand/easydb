
# Exposed Functions -------------------------------------------------------

## Connect to Database -----------------------------------------------------

# Initialise DB

#' Initialise Configuration Store
#'
#' Create a file to store your database configurations in.
#'
#' @param config_file path to create a new config file to store database configurations
#'
#' @return invisibly returns path to config file
#' @export
#'
#' @examples
#'
#' # Choose config file path
#' # Do NOT use tempfile in practice.
#' # Choose a fixed location such as '~/.easydb'
#' config <- tempfile('.example_config')
#'
#' # Initialise Configuration File
#' easydb_init(config)
#'
easydb_init <- function(config_file){
  assert_config_file_appropriate(config_file)

  config_file <- normalizePath(config_file, mustWork = FALSE, winslash = "/")

  if(file.exists(config_file)){
    cli::cli_alert_info('Config file already exists [{.path {config_file}}]. Skipping config file creation')
    return(invisible(config_file))
  }

  cli::cli_inform('Creating config file at:')
  cli::cli_alert('{.path {config_file}}')
  file.create(config_file)

  cli::cli_rule()
  cli::cli_alert_success('Config file created at {.path {config_file}}')
  return(invisible(config_file))
}

#' Easy Database Connection
#'
#' Easily connect to a database.
#' When connecting to a database for the first time, you will be prompted for connection details.
#' Configuration details will be stored in the user-specified 'configuration file'.
#' The next time you run the same command, config details will be automatically retreived from the config file.
#' Any usernames and passwords are stored in your system credential manager (not on-disk)
#'
#'
#' @param dbname name of database (string)
#' @param from_scratch should we delete any current config / credentials for databases with the supplied name and start again? (logical)
#' @param config_file path to yaml file containing configuration information about databases (port, host, etc. ) (string)
#'
#' @return connection to database (connection)
#' @export
#'
#' @examples
#' if(interactive()) {
#'
#'   # Choose config file path
#'   # Do NOT use tempfile in practice.
#'   # Instead, choose a fixed location such as '~/.easydb'
#'   config <- tempfile('.example_config')
#'
#'   # Initialise config file
#'   easydb_init(config)
#'
#'   # Connect to SQLite database
#'   path_to_db <- system.file(package = 'easydb', 'testdbs/mtcars.sqlite')
#'   con <- easydb_connect(dbname = path_to_db, config_file = config)
#'
#'   # Disconnect from database when finished
#'   easydb_disconnect(con)
#' }
easydb_connect <- function(dbname, config_file, from_scratch = FALSE) {

  # Assertions
  assertthat::assert_that(assertthat::is.string(dbname))
  assertthat::assert_that(assertthat::is.string(config_file))


  # Make sure supplied configuration filepath exists
  if(!file.exists(config_file)){
    cli::cli_abort(
      'No config file found at {.path {config_file}}.
      If you want to create a new configuration file at this location, please run `easydb_init("{.path {config_file}}")`')
  }

  # Get/Set Config
  cli::cli_h2("Database Configuration")

  # Delete database entry if running from scratch
  if(from_scratch & utils_database_already_in_yaml(dbname, file = config_file))
    utils_database_remove_entry_from_yaml(dbname, file = config_file)

  if(from_scratch)
    utils_database_credentials_delete(dbname)

  config <- utils_database_get_or_set_config(dbname = dbname, file = config_file)
  driver <- config$driver
  assert_driver_supported(driver)

  # Choose Driver
  cli::cli_alert_info("Checking drivers are installed")
  drv <- utils_driver_name_to_function(driver)
  cli::cli_alert_success("Required drivers installed")


  # Get / Set Credentials
  cli::cli_h2("Credentials")

  # Override creds_required variable for sqlite databses
  if (config$creds_required){

    creds <- utils_database_get_or_set_creds(dbname = dbname)
  }
  else{
    cli::cli_alert_info("No credentials required, skipping credential retrieval.")
    #cli::cli_alert_info("If your database requires a username & password please rerun with {.code creds_required = TRUE}")
    creds <- list(username = NULL, password = NULL)
  }

  # Add reading from yaml config

  # Connections takes different arguments depending on driver function ... so we need to build a separate call

  if (driver == "mysql") {
    connection <- DBI::dbConnect(
      drv = drv,
      dbname = dbname,
      username = creds$username,
      password = creds$password,
      port = config$port,
      host = config$host,
      ssl.key = config$ssl_key,
      ssl.ca = config$ssl_ca,
      ssl.cert = config$ssl_cert
    )
  } else if (driver == "postgresql") {
    connection <- DBI::dbConnect(
      drv = drv,
      dbname = dbname,
      user = creds$username,
      password = creds$password,
      port = config$port,
      host = config$host
    )
  } else if (driver == "sqlite") {
    connection <- DBI::dbConnect(
      drv = drv,
      dbname = dbname
    )
  } else {
    cli::cli_abort("Developer forgot to add a custom connection to this ifelse statement (see format of above statements). Please tell them to add relevant code for {driver} databases")
  }


  cli::cli_alert_success("Succesfully connected to database {.path {dbname}}")
  return(connection)
}




#' Disconnect from database
#'
#' Simple wrapper around [DBI::dbDisconnect()]
#'
#' @param connection coneection generated by [easydb_connect]
#'
#' @return Invisibly returns TRUE
#' @export
#' @inherit easydb_connect examples
easydb_disconnect <- function(connection){
  DBI::dbDisconnect(connection)
}


#' Available Databases
#'
#' List databases with configuration details stored in a configuration file.
#'
#' @inheritParams easydb_connect
#'
#' @return database names (character vector)
#' @export
#'
#' @examples
#' path_to_config = tempfile()
#' easydb_available_databases(path_to_config)
easydb_available_databases <- function(config_file){
  if(!file.exists(config_file)){
    cli::cli_inform(
      c('!'="No config file found at {.path {config_file}}.
      To create one, use `easydb_init({.field \'{config_file}\'})`"
      ))
    return(invisible(NULL))
  }

  config_file <- normalizePath(config_file, mustWork = FALSE)

  yaml_list <- yaml::read_yaml(config_file)

  if(!is.null(yaml_list)){
    databases_described <- names(yaml_list)
    names(databases_described) <- rep(">", times = length(databases_described))
  }
  else{
    databases_described <- 'No database connections defined'
    }

  cli::cli_h2('Databases:')
  cli::cli_bullets(databases_described)

  cli::cli_h2('Notes')
  cli::cli_alert_info('Config file: {.path {config_file}}')
  cli::cli_alert_info(
    "Add more database connections using `easydb_connect(<dbname>, {.field \'{config_file}\'})`")

  return(invisible(unname(databases_described)))
}

#' Check config filepath is appropriate
#'
#' Ensures file is hidden, in a folder that exists, and that has read and write permissions.
#' The file itself doesn't already have to exist
#'
#' @param file path to config file (string)
#'
#' @return invisibly returns TRUE
#'
assert_config_file_appropriate <- function(file){
  assertthat::assert_that(assertthat::is.string(file))

  # make sure its not zero-char
  assertthat::assert_that(nchar(file) > 0)

  # Make sure filepath doesn't point to a directory
  if(file.exists(file) && dir.exists(file))
   cli::cli_abort("A folder already exists at {.path {file}}. Please supply the full path of a configuration yaml that you want to use/create (not just a path to the parent folder!)")


  # Ensure folder your file is in exists
  file_dirpath = dirname(file)
  if(!dir.exists(file_dirpath))
    cli::cli_abort('Folder does NOT exist: {.path {file_dirpath}}')

  # Ensure you have read and write permissions to selected folder
  has_read_permissions = file.access(file_dirpath, mode = 4) == 0
  has_write_permissions = file.access(file_dirpath, mode = 2) == 0
  if(!has_read_permissions | !has_write_permissions)
    cli::cli_abort('Must have both read and write permissions for folder {.path {dirname(file)}}. Current permissions [Write: {has_write_permissions}, Read: {has_read_permissions}')

  # Ensure file is hidden (prefix '.')
  basename = basename(file)
  if (!startsWith(basename, prefix = "."))
    cli::cli_abort("Config file should almost always be a hidden file. Consider changing {.path {basename}} to {.file {paste0('.', basename)}}")


  # Ensure path given is absolute
  if(!is_absolute_path(file))
    cli::cli_abort('Config file described using a relative path. easydb requires config file path to be {.strong absolute} (e.g. "~/.easydb")')

  return(invisible(TRUE))
}

# Database Config Utilities ------------------------------------------------------

#' Create/Retrieve database credentials
#'
#' Retrieves credentials (username and password) from os credential store using keyring package.
#'
#' @param dbname  Name of database to store/retrieve credentials for (string)
#'
#' @return Invisibly returns list of username and password
#'
#' @examples
#' \dontrun{
#' creds <- easydb::util_get_database_creds(
#'   service = "R-keyring-test-service",
#'   username = "donaldduck"
#' )
#' creds$username
#' creds$password
#' }
utils_database_get_or_set_creds <- function(dbname) {
  assertthat::assert_that(assertthat::is.string(dbname))

  dbname_found <- dbname %in% keyring::key_list(dbname)[["service"]]
  username <- keyring::key_list(dbname)[["username"]][keyring::key_list(dbname)[["service"]] == dbname]
  username_found <- length(username) == 1

  multiple_usernames_found <- length(username) > 1

  if (multiple_usernames_found) {
    cli::cli_abort("multiple usernames found for dbname [{service}]. There should only be one username per database credential entry")
  }


  # If no key exists, ask if user wants to create one
  if (!dbname_found | !username_found) {
    cli::cli_alert_info("Existing credential set not found")

    create_new_passcode <- utils::menu(title = "Existing credentials not found. Do you want to add a new username & password?", choices = c("Yes", "No"))

    if (create_new_passcode != 1) {
      cli::cli_alert_info("User chose not to create a new passcode\n\n")
      cli::cli_abort("Could not find credentials. Please check service and username are appropriate")
    }

    # Create new key
    #cli::cli_alert_info("Creating a new db user credentials")
    user <- readline("Username: ")
    pass <- askpass::askpass(prompt = "Password (leave blank for null)")
    if(is.null(pass)) pass <- ""
    keyring::key_set_with_value(service = dbname, username = user, password = pass)

    return(utils_database_get_or_set_creds(dbname = dbname)) # run this same function again
  }

  password <- keyring::key_get(service = dbname, username = username)

  cli::cli_alert_success("Found credential service and username")

  creds <- list(username = username, password = password)

  return(invisible(creds))
}

utils_database_credentials_delete <- function(dbname){
  creds = keyring::key_list(dbname)

  if (nrow(creds) > 0)  # If a username/password pair exists under the 'dbname' key then delete
    keyring::key_delete(service = dbname, username = creds$username)


  return(invisible(TRUE))
}

#' Interactive getting/setting database configurations
#'
#'
#' @param dbname nane of database (string)
#' @param file yaml file to store database configuration information
#'
#' @return list describing database configuration
#'
utils_database_get_or_set_config <- function(dbname, file) {
  assertthat::assert_that(assertthat::is.string(dbname))
  assertthat::assert_that(assertthat::is.string(file))

  if(!file.exists(file)){
    cli::cli_alert_info("Creating a new config file since none found at {.path {file}}")
    file.create(file)
  }

  # If entry is in database, overwrite
  if (utils_database_already_in_yaml(dbname, file = file)) {
    cli::cli_inform("Found configuration entry for database [{.strong {dbname}}] in config file {.path {file}}")
    config_list <- utils_database_read_yaml(dbname, file)
    return(config_list)
  }

  # If db doesn't already have config entry - ask user to make one
  user_wants_to_create_config <- utils::menu(title = "Couldn't find an existing config entry for database.\nDo you want to create a new configuration entry?", choices = c("Yes", "No"))

  if (is.na(user_wants_to_create_config) | user_wants_to_create_config != 1) {
    cli::cli_abort("User chose not to create a config entry and no config file exists so quitting early")
  }


  driver_n <- utils::menu(choices = supported_drivers(), title = "Driver: ")
  driver <- supported_drivers()[driver_n]

  config_list <- utils_database_get_driver_specific_config_properties(file = file, dbname = dbname, driver = driver)

  utils_database_write_yaml(
    file = file,
    dbname = config_list$dbname,
    driver = config_list$driver,
    port = config_list$port,
    host = config_list$host,
    ssl_cert = config_list$ssl_cert,
    ssl_key = config_list$ssl_key,
    ssl_ca = config_list$ssl_ca,
    creds_required = config_list$creds_required,
    append = TRUE
  )

  return(config_list)
}



utils_database_get_driver_specific_config_properties <- function(file, dbname, driver){
  assertthat::assert_that(assertthat::is.string(file))
  assertthat::assert_that(assertthat::is.string(dbname))
  assert_driver_supported(driver)

  if(driver == "sqlite") {
    ask_host = FALSE
    ask_port = FALSE
    ask_ssl = FALSE
    ask_if_creds_required = FALSE
  }
  else if (driver == "postgresql") {
    ask_host = TRUE
    ask_port = TRUE
    ask_ssl = FALSE
    ask_if_creds_required = TRUE
  }
  else if (driver == "mysql") {
    ask_host = TRUE
    ask_port = TRUE
    ask_ssl = TRUE
    ask_if_creds_required = TRUE
  }
  else {
   cli::cli_abort('Developer forgot to indicate which database configuration properties should be set for the driver {.strong {driver}} despite it being supported. Please raise a github issue')
  }

  #All possible paramaters must be first set here as null
  host <- NULL
  port <- NULL
  ssl_cert <- NULL
  ssl_key <- NULL
  ssl_ca <- NULL
  creds_required <- FALSE

  # Host
  if(ask_host)
    host <- utils_user_input_retrieve_free_text("Host [NA]: ", default = NULL, type = "string")

  # Port
  if(ask_port)
    port <- utils_user_input_retrieve_free_text("Port [NA]: ", default = NULL, type = "number")


  # SSL
  if(ask_ssl){
    ssl_required <- utils::menu(title="Do you need to point to SSL certificates?", choices = c("Yes", "No"))

    if (ssl_required == 1) {
      ssl_ca <-  utils_file_choose_looped("Please select your Certificate Authority (CA) certificate file (*.pem).")

      # Add options to supply optional ssl files
      requires_ssl_cert <- utils::menu(choices = c("Yes", "No"), title = "Would you like to supply an OPTIONAL server public key certificate file")
      if(requires_ssl_cert == 1)
        ssl_cert <- utils_file_choose_looped("Please select your SSL Certificate (*.pem).")
      else
        ssl_cert <- NULL
      requires_ssl_ca <- utils::menu(choices = c("Yes", "No"), title = "Would you like to supply an OPTIONAL server private key file.")
      if(requires_ssl_ca == 1)
        ssl_key <- utils_file_choose_looped("Please select your Private SSL Key (*.pem).")
      else
        ssl_key <- NULL

    } else {
      ssl_cert <- NULL
      ssl_key <- NULL
      ssl_ca <- NULL
    }
  }

  # Credentials
  if(ask_if_creds_required){
    cred_choice = utils::menu(choices = c("Yes", "No"), title = "Does the database require a username & password?")

    if(cred_choice == 1)
      creds_required = TRUE
    else
      creds_required = FALSE
  }

  config_list <- list(
    file = file,
    dbname = dbname,
    driver = driver,
    port = port,
    host = host,
    ssl_cert = ssl_cert,
    ssl_key = ssl_key,
    ssl_ca = ssl_ca,
    creds_required = creds_required
    )

  return(config_list)
}

#' Write database yaml
#'
#' Writes database config details into a yaml. Usernames and passwords are never saved in this yaml file
#'
#' @param dbname name of database
#' @param driver name of driver
#' @param port database port
#' @param host database host
#' @param file where config file should be located (will be produced if it doesn't already exist)
#' @param append should config file be appended or overwritten? Defualts to append. Don't change unless you know what you're doing
#' @param ssl_cert path to ssl certificate (string)
#' @param ssl_key path to ssl key (string)
#' @param ssl_ca path to ssl CA certificate (string)
#' @param creds_required are credentials (username/password) required for this database (flag)
#'
#' @return path to config yaml containing the new database info (string)
#'
utils_database_write_yaml <- function(dbname, driver, creds_required = FALSE, port = NULL, host = NULL, ssl_cert = NULL, ssl_key = NULL, ssl_ca = NULL, file, append = TRUE) {


  # Assertions
  assertthat::assert_that(assertthat::is.string(file))
  assertthat::assert_that(assertthat::is.string(dbname))
  assertthat::assert_that(assertthat::is.flag(append))
  assertthat::assert_that(assertthat::is.flag(creds_required))


  if (!is.null(port)) {
    assertthat::assert_that(assertthat::is.number(port))
  }

  if (!is.null(host)) {
    assertthat::assert_that(assertthat::is.string(host))
  }

  if (!is.null(ssl_cert)) {
    assertthat::assert_that(assertthat::is.string(ssl_cert))
    assertthat::assert_that(file.exists(ssl_cert))
  }

  if (!is.null(ssl_key)) {
    assertthat::assert_that(assertthat::is.string(ssl_key))
    assertthat::assert_that(file.exists(ssl_key))
  }

  if (!is.null(ssl_ca)) {
    assertthat::assert_that(assertthat::is.string(ssl_ca))
    assertthat::assert_that(file.exists(ssl_ca))
  }

  if (!file.exists(file)) {
    file.create(file)
    cli::cli_alert_info("File {.path {file}} was created, since no existing file was found")
  }



  # Make sure driver is supported
  assert_driver_supported(driver = driver)
  utils_driver_name_to_function(driver = driver)

  # Check if config yaml already has entry for this database. If so delete it so we can make a new one
  if (utils_database_already_in_yaml(dbname = dbname, file = file)) {
    cli::cli_alert_warning("Found existing entry configuration for database: [{dbname}] in file {.path {file}}. Overwriting...")
    utils_database_remove_entry_from_yaml(dbnames = dbname, file = file)
  }


  # Format configuration as yaml list
  db_entry <- list(new_db_entry = list(
    "driver" = driver,
    "port" = port,
    "host" = host,
    "ssl_cert" = ssl_cert,
    "ssl_key" = ssl_key,
    "ssl_ca" = ssl_ca,
    "creds_required" = creds_required # add new db paramaters here
  ))
  names(db_entry) <- dbname
  yaml_string <- yaml::as.yaml(db_entry)


  # Write database configuration to yaml file
  assertthat::assert_that(assertthat::is.string(yaml_string))
  cli::cli_alert_info("Adding database: [{dbname}] to yaml file {.path {file}}")

  # Write yaml string to config file
  write(yaml_string, file = file, ncolumns = 1, append = append)

  # Normalise filepath and let user know where the config file is located
  filepath_normalised <- normalizePath(file)
  cli::cli_alert_info("configuration added to {.path {filepath_normalised}}")

  return(file)
}

#' Read the database config
#'
#'
#'
#' @param dbname name of database whose config you want to read
#' @param file path to config yaml
#'
#' @return list with config
#'
utils_database_read_yaml <- function(dbname, file) {
  assertthat::assert_that(assertthat::is.string(dbname))
  assertthat::assert_that(file.exists(file))

  yaml_list <- yaml::read_yaml(file)

  if (!dbname %in% names(yaml_list)) {
    cli::cli_abort("Could not find an entry for database '{.strong {dbname}}' in the config file {.path {file}}.")
  }

  config_list <- yaml_list[[dbname]]
  return(config_list)
}

#' Database Utils
#'
#' Check if a yaml contains an entry describing a given database
#'
#' @param dbname database name (character)
#' @param file file (string)
#'
#' @return true if yaml entry for dbname found, otherwise false (logical)
#'
utils_database_already_in_yaml <- function(dbname, file) {
  assertthat::assert_that(is.character(dbname))
  assertthat::assert_that(assertthat::is.string(file))
  #assertthat::assert_that(file.exists(file))

  # cli::cli_alert_info("Checking if an entry for database: {dbname} already exists in config file {file}")

  if(!file.exists(file)) { return(FALSE) }

  db_config <- yaml::read_yaml(file = file)

  databases_with_config_entry <- names(db_config)

  return(dbname %in% databases_with_config_entry)
}

#' Delete database config entries from yaml
#'
#' @param dbnames names of databases to delete from yaml (character)
#' @param file path to config yaml (string)
#'
#' @return Run for its side effects
#'
utils_database_remove_entry_from_yaml <- function(dbnames, file) {
  assertthat::assert_that(is.character(dbnames))
  assertthat::assert_that(assertthat::is.string(file))
  assertthat::assert_that(file.exists(file))


  yaml_list <- yaml::read_yaml(file)
  databases_already_not_in_yaml <- dbnames[!dbnames %in% names(yaml_list)]
  databases_to_delete_that_are_in_yaml <- dbnames[dbnames %in% names(yaml_list)]


  if (length(databases_to_delete_that_are_in_yaml) == 0) {
    cli::cli_abort("All databases you tried to delete [{dbnames}] were already absent from the yaml file {.path {file}}")
  } else if (length(databases_to_delete_that_are_in_yaml) < length(dbnames)) {
    cli::cli_alert_info("No need to delete databases: [{databases_already_not_in_yaml}]. They are already absent from the file {.path {file}}")
  }

  cli::cli_alert_info("Deleting databases: [{databases_to_delete_that_are_in_yaml}] from the yaml file {.path {file}}")

  yaml_list_after_deletion <- yaml_list[!names(yaml_list) %in% dbnames]

  if (length(yaml_list_after_deletion) == 0) {
    cat(NULL, file = file)
  } # Empty file contents if only db present was the one you're trying to remove
  else {
    yaml::write_yaml(yaml_list_after_deletion, file = file)
  }

  return(invisible(TRUE))
}

#' get user input
#'
#' @param message message - tell user what information to input
#' @param default if user enters no data, this value will be returned (NULL)
#' @param type return type
#'
#' @return user input formatted according to type. If user does not enter anything will return value of \code{default}
#'
utils_user_input_retrieve_free_text <- function(message, default = NULL, type = c("string", "number")) {
  type <- rlang::arg_match(type)
  res <- readline(message)

  if (res == "") {
    return(default)
  } else {
    if (type == "string") {
      res <- as.character(res)
    } else if (type == "number") {
      res <- as.numeric(res)
    }

    return(res)
  }
}
## Drivers ----------------------------------------------------------
#' List supported drivers
#'
#' @return returns a vector of supported database drivers (character).
#' Names relate to the R packages containing the relevant driver function
#' @export
supported_drivers <- function() {
  c(RSQLite = "sqlite", RMariaDB = "mysql", RPostgres = "postgresql")
}

assert_driver_supported <- function(driver) {
  assertthat::assert_that(assertthat::is.string(driver))
  supported_drivers <- supported_drivers()

  # Drivers supported
  if (!driver %in% supported_drivers) {
    cli::cli_abort("Driver [{driver}] is not supported. Supported drivers include {supported_drivers()}")
  }

  # Is required package installed
  required_package <- names(supported_drivers)[match(driver, supported_drivers)]
  if (!rlang::is_installed(pkg = required_package)) {
    cli::cli_abort("Package {required_package} is required to connect to a {driver} database. Install with install.packages('{required_package}')")
  }

  invisible(TRUE)
}

utils_driver_name_to_function <- function(driver) {
  assert_driver_supported(driver)

  drv <- NULL

  if (driver == "sqlite") {
    drv <- RSQLite::SQLite()
  } else if (driver == "mysql") {
    drv <- RMariaDB::MariaDB()
  } else if (driver == "postgresql") {
    drv <- RPostgres::Postgres()
  } else {
    cli::cli_abort("Package maintainer needs to add another elseif statement specifying the driver function of this already-supported driver [{driver}]. Please open a github issue and paste this error message in the body to let them know!")
  }

  return(drv)
}


utils_file_choose_looped <- function(prompt){
  readline(prompt = paste0(prompt, " [Press enter to continue] ", collapse = ""))
  f = tryCatch(expr = {
      file.choose()
    },
    error = function(err){
      return(utils_file_choose_looped())
    })

  return(f)
}


# Assorted Utilities ------------------------------------------------------

is_absolute_path <- function(path){
  assertthat::assert_that(assertthat::is.string(path))
  assertthat::assert_that(nchar(path) > 0)

  is_absolute <- startsWith(x = path, prefix = "~") |
    startsWith(x = path, prefix = "/") |
    grepl(x = path, pattern = "^.:")

  return(is_absolute)
}


