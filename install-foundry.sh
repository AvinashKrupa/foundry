#!/usr/bin/env bash
source ./install-actions.sh

# --- common functions ---
# Colors
red='\033[0;31m'
green='\033[1;32m'
cyan='\033[1;36m'
reset='\033[0m'

NUMBER_FORMAT='^[0-9]+$'

TIMESTAMP=$(date +%d%m%y%H%M%S)

BASEDIR="$( cd "$(dirname "$0")" ; pwd -P )"
LIB_DIR="$BASEDIR"/lib
INSTALL_CHOICE=ONPREM_DEV
USER_INPUT_FILE="$1"
RANDOM_VAR=$RANDOM
FLYWAY_CONTAINER_NAME="flyway-"$RANDOM_VAR
FABRIC_CONTAINER_NAME="foundry-"$RANDOM_VAR
PULL_IMAGES=true
SETUP_TYPE='singleContainer'

prepare_fabric_variables() {
	is_tomcat_ssl_enabled="false"
	tomcat_connector_protocol=HTTP/1.1
	if [ "$COM_PROTOCOL" = "https" ] ; then
		is_tomcat_ssl_enabled="true"
	fi

}

create_container_artifact_dirs() {
	mkdir "$BASEDIR"/$FLYWAY_CONTAINER_NAME
	mkdir "$BASEDIR"/$FABRIC_CONTAINER_NAME
}

create_env_files() {
	replace_variables_in_file  "$BASEDIR"/templates/flyway-template.env "$BASEDIR"/$FLYWAY_CONTAINER_NAME/.env
	replace_variables_in_file  "$BASEDIR"/templates/foundry-template.env "$BASEDIR"/$FABRIC_CONTAINER_NAME/.env	
}

update_docker_compose_file() {

    if [[ "$IS_MYSQL_CONTAINER_REQUIRED" == "true" ]] ; then
		cp "$BASEDIR"/templates/flyway-mysql-docker-compose-tmpl.yml "$BASEDIR"/$FLYWAY_CONTAINER_NAME/docker-compose.yml
	    cp "$BASEDIR"/templates/foundry-mysql-docker-compose-tmpl.yml "$BASEDIR"/$FABRIC_CONTAINER_NAME/docker-compose.yml
	else
        cp "$BASEDIR"/templates/flyway-docker-compose-tmpl.yml "$BASEDIR"/$FLYWAY_CONTAINER_NAME/docker-compose.yml
	    cp "$BASEDIR"/templates/foundry-docker-compose-tmpl.yml "$BASEDIR"/$FABRIC_CONTAINER_NAME/docker-compose.yml
	fi

	sed -i -e "s/server_port/$SERVER_PORT/g" "$BASEDIR"/$FABRIC_CONTAINER_NAME/docker-compose.yml
	sed -i -e "s/server_port/$SERVER_PORT/g" "$BASEDIR"/$FABRIC_CONTAINER_NAME/docker-compose.yml
	sed -i -e "s/FLYWAY_CONTAINER_NAME/$FLYWAY_CONTAINER_NAME/g" "$BASEDIR"/$FLYWAY_CONTAINER_NAME/docker-compose.yml
	sed -i -e "s/FABRIC_CONTAINER_NAME/$FABRIC_CONTAINER_NAME/g" "$BASEDIR"/$FABRIC_CONTAINER_NAME/docker-compose.yml
	sed -i -e "s/\$FABRIC_DATABASE_BUILD_VERSION/$FABRIC_DATABASE_BUILD_VERSION/g" "$BASEDIR"/$FLYWAY_CONTAINER_NAME/docker-compose.yml
	sed -i -e "s/\$FABRIC_BUILD_VERSION/$FABRIC_BUILD_VERSION/g" "$BASEDIR"/$FABRIC_CONTAINER_NAME/docker-compose.yml
	if [ "$COM_PROTOCOL" = "https" ] ; then
		updated_https_keystore_file_path=$(echo $KEYSTORE_FILE | sed 's_/_\\/_g')
		sed -i -e "s/keystore_file_path/$updated_https_keystore_file_path/g" "$BASEDIR"/$FABRIC_CONTAINER_NAME/docker-compose.yml
		sed -i -e "s/#//g" "$BASEDIR"/$FABRIC_CONTAINER_NAME/docker-compose.yml
	fi
}

remove_existing_container() {
	EXISTING_CONTAINER_ID=$(docker ps -a -f name=$1 -f status=exited -q)
	if [ ! -z $EXISTING_CONTAINER_ID ]; then
		echo "Killing existing $1 container"
		docker rm $EXISTING_CONTAINER_ID
	fi
}

clean_docker() {
	remove_existing_container $FLYWAY_CONTAINER_NAME
	remove_existing_container $FABRIC_CONTAINER_NAME
}

create_container() {
	if  [ "$PULL_IMAGES" = true ] ; then		
		docker-compose pull
	fi
	docker-compose up -d
}

check_prerequisites(){

	local error_count=0

	if ! is_command_present java; then
		log_error 'Java is required for installing the Volt Foundry Docker image. If already installed, add Java installation directory to PATH environment variable'
		error_count=$((error_count+1))
	fi
	
	if ! is_command_present docker-compose; then
		log_error 'docker/docker-compose is required for installing the Volt Foundry Docker image.'
		error_count=$((error_count+1))
	fi

	if [[ "$error_count" -gt 0 ]]; then
		exit 1
	fi
}

execute_database_migrations() {
	cd "$BASEDIR"/$FLYWAY_CONTAINER_NAME
	create_container
	log_msg "Waiting for DB migrations to complete (this may take upto 10 minutes)..."
	docker logs -f $FLYWAY_CONTAINER_NAME > "$BASEDIR"/$FLYWAY_CONTAINER_NAME/dbmigration-${TIMESTAMP}.log
	MIGRATION_STATUS=$(docker container wait $FLYWAY_CONTAINER_NAME)
	if [ -z "$MIGRATION_STATUS" ]
	then
		log_error_and_exit "Error occured while creating flyway container."		
	elif [ $MIGRATION_STATUS -eq 0 ]
	then
		log_msg "DB migrations complete."
	else
		log_error "Error occured while executing DB migrations."
		log_error_and_exit "Check "$BASEDIR"/$FLYWAY_CONTAINER_NAME/dbmigration-${TIMESTAMP}.log for more information"
	fi
}

start_fabric_server() {
	cd "$BASEDIR"/$FABRIC_CONTAINER_NAME
	create_container
	cd "$BASEDIR"
}

check_prerequisites

get_user_inputs

prepare_db_variables

prepare_fabric_variables

encrypt_variables

create_container_artifact_dirs

create_env_files

update_docker_compose_file

clean_docker

execute_database_migrations

start_fabric_server

if [ "$USE_EXISTING_DB" == "false" ]; then
	generate_upgrade_properties_file
fi

wait_for_fabric_startup
print_hr

if [[ "$USE_EXISTING_DB" == "false" && "$OWNER_REGISTRATION_REQUIRED" == "true" ]]; then
    log_msg "Performing Owner Registration..."
	do_auth_environment_registration
	print_hr
fi
print_install_end_notes
print_hr
