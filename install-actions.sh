KUBEADM_VERSION=1.27.6
KUBELET_VERSION=1.27.6
KUBECTL_VERSION=1.27.6

LOG_DIR="${BASEDIR}"/logs

create_log_file() {
	mkdir -p "$LOG_DIR"
	> "${INSTALL_LOG_LOCATION}"
}

write_to_log_file() {
	printf "$1\n" >> "${INSTALL_LOG_LOCATION}"
}

common_preflight_log(){
	{
	echo
	decoratorLarge
	echo -e "$(date)\n"
	echo -e "OS $(cat /etc/os-release | head -n 2)\n"
	echo -e "$(java -version 2>&1)\n"
	echo -e "$((lscpu | egrep 'CPU\(s\)' | head -n 1) && (lscpu | egrep 'Model name'))\n"
	echo -e "$(cat /proc/meminfo | head -n 3)\n"
	} >> "${INSTALL_LOG_LOCATION}"
}

load_inputs_from_props_file() {
	. "$BASEDIR/$1"
}

log_error() {
	printf "${red}$1${reset}\n"
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
		write_to_log_file "$1"
	fi
}

log_error_and_exit() {
    log_error "$1";
    exit 1;
}

log_msg() {
	printf "${green}$1${reset}\n"
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
	write_to_log_file "$1"
	fi
}


log_info() {
	printf "$1\n"
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
	printf "$1\n" >> "${INSTALL_LOG_LOCATION}"
	fi
}

is_command_present() {
	# https://stackoverflow.com/a/677212/340290
	hash "$1" 2>/dev/null ;
	# command -v "$1" >/dev/null 2>&1 ;
}

decoratorLarge() {
	cols=$(tput cols)
	for ((i=0; i<cols/2; i++))
	do {
		printf "="
		if [ "$SETUP_TYPE" == "kubernetes" ]; then
		printf "=" >> "${INSTALL_LOG_LOCATION}"
		fi
		}
	done;
	echo
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
		echo >> "${INSTALL_LOG_LOCATION}"
	fi
}

decoratorSmall() {
	cols=$(tput cols)
	for ((i=0; i<cols/2; i++))
	do {
		printf "-"
		if [ "$SETUP_TYPE" == "kubernetes" ]; then
		printf "-" >> "${INSTALL_LOG_LOCATION}"
		fi
		}
	done;
	echo
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
		echo >> "${INSTALL_LOG_LOCATION}"
	fi
}


print_header_h1() {
	echo
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
		echo >> "${INSTALL_LOG_LOCATION}"
	fi
	decoratorLarge
	printf "$1\n"
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
	printf "$1\n" >> "${INSTALL_LOG_LOCATION}"
	fi
	decoratorLarge
}


print_header_h2() {
	printf "\n$1\n"
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
	printf "\n$1\n" >> "${INSTALL_LOG_LOCATION}"
	fi
	decoratorSmall
}


print_hr() {
	# http://wiki.bash-hackers.org/snipplets/print_horizontal_line#a_line_across_the_entire_width_of_the_terminal
	# printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	decoratorSmall
}

is_docker_command_present(){
	if is_command_present docker; then
		echo -e "$(docker -v)\n" >> "${INSTALL_LOG_LOCATION}"
	else
		echo -e "Docker not installed before installation of Foundry\n" >> "${INSTALL_LOG_LOCATION}"
	fi
}

is_kubectl_command_present(){
	if is_command_present kubectl; then
		echo -e "KUBECTL $(kubectl version --short 2>&1 | head -n 1)\n" >> "${INSTALL_LOG_LOCATION}"
	else
		echo -e "KUBECTL is not installed before installation of Foundry\n" >> "${INSTALL_LOG_LOCATION}"
	fi
}

is_kubelet_command_present(){
	if is_command_present kubelet; then
		echo -e "KUBELET Client Version: $(kubelet --version | awk '{print $2;}')" >> "${INSTALL_LOG_LOCATION}"
	else
		echo -e "KUBELET is not installed before installation of Foundry" >> "${INSTALL_LOG_LOCATION}"
	fi
}

is_kubeadm_command_present(){
	if is_command_present kubeadm; then
		echo -e "KUBEADM Client Version: $(kubeadm version -o short)" >> "${INSTALL_LOG_LOCATION}"
	else
		echo -e "KUBEADM is not installed before installation of Foundry" >> "${INSTALL_LOG_LOCATION}"
	fi
}

is_dig_command_present(){
	if is_command_present dig; then
		echo -e "Dig status: Installed\n" >> "${INSTALL_LOG_LOCATION}"
	else
		echo -e "Dig status: Not Installed\n" >> "${INSTALL_LOG_LOCATION}"
	fi
}

swap_status_check(){
	swap_status=$(swapon -s)
	if [ -z "$swap_status" ]; then
		echo -e "Swap status: OFF\n" >> "${INSTALL_LOG_LOCATION}"
	else
		echo -e "Swap status: ON\n" >> "${INSTALL_LOG_LOCATION}"
	fi
}

check_if_file_exists(){
	 [ -f "$1" ]
}


convert_str_to_lower_case() {
	echo "$1" | tr '[:upper:]' '[:lower:]'
}

convert_str_to_upper_case() {
	echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Prepares DB related variables
prepare_db_variables(){
	
    if [[ "$IS_MYSQL_CONTAINER_REQUIRED" == "true" ]] ; then
		DB_HOST=foundry-mysql
		DB_PORT=3306
		DB_USER=root
	fi

	if [ "${USE_EXISTING_DB}" == "Y" -o "${USE_EXISTING_DB}" == "y" ]; then
		USE_EXISTING_DB="true"
	else
		USE_EXISTING_DB="false"
	fi
	
	PERFORM_FLYWAY_REPAIR=$USE_EXISTING_DB
  IS_MYSQL_CLUSTER="false"

	if [ "${DB_TYPE}" == "mysqlcluster" ]; then
      IS_MYSQL_CLUSTER="true"
      DB_TYPE="mysql"
  fi
	
	admindb=${DB_PREFIX}admindb${DB_SUFFIX}
	reportsdb=${DB_PREFIX}mfreportsdb${DB_SUFFIX}
	idconfigdb=${DB_PREFIX}idconfigdb${DB_SUFFIX}
	accountsdb=${DB_PREFIX}mfaccountsdb${DB_SUFFIX}
	consoledb=${DB_PREFIX}mfconsoledb${DB_SUFFIX}
	kpnsdb=${DB_PREFIX}kpnsdb${DB_SUFFIX}

	admin_db_type=$(convert_str_to_lower_case ${DB_TYPE})
	if [ "${DB_TYPE}" == "oracle" ]; then
		accountsdb=$(convert_str_to_upper_case $accountsdb)
		reportsdb=$(convert_str_to_upper_case $reportsdb)
		idconfigdb=$(convert_str_to_upper_case $idconfigdb)
		consoledb=$(convert_str_to_upper_case $consoledb)
		admindb=$(convert_str_to_upper_case $admindb)
		kpnsdb=$(convert_str_to_upper_case $kpnsdb)
	fi
	auth_db_user=${DB_USER}
	kpns_db_user=${DB_USER}
	waas_db_user=${DB_USER}
	reports_db_user=${DB_USER}
	admin_db_user=${DB_USER}
	accounts_db_user=${DB_USER}
	metrics_driver=${DB_TYPE}
	fabric_db_type=${DB_TYPE}

	if [ "${DB_TYPE}" == "sqlserver" ]; then

		 db_choice="MSSQL";
		 fabric_db_type=$(convert_str_to_lower_case $db_choice)
	else
		db_choice=$(convert_str_to_upper_case $DB_TYPE)
	fi

	if [ "${db_choice}" == "MSSQL" ]; then

		auth_db_datasource="com.microsoft.sqlserver.jdbc.SQLServerDataSource"
		admin_db_dialect="com.kony.console.admin.dialect.CustomSQLServerDialect"
		kpns_db_dialect="com.kony.kms.dialect.KMSSQLServerDialect"
		kpnsdb_defaultcatalog=${kpnsdb}
		kpns_db_delegate_class="org.quartz.impl.jdbcjobstore.MSSQLDelegate"
		db_dialect="org.hibernate.dialect.SQLServerDialect"
		auth_db_dialect=${db_dialect}
		db_driver="com.microsoft.sqlserver.jdbc.SQLServerDriver"
		db_validation_query="SELECT 1"
		metrics_module_name="com.microsoft"

		if [ -z "${DB_PORT}" ]; then
			DB_PORT=1433
			authconfigdb_url="jdbc:sqlserver://${DB_HOST};databasename=${idconfigdb};sendStringParametersAsUnicode=true;encrypt=false;"
			waasdb_url="jdbc:sqlserver://${DB_HOST};databasename=${consoledb};sendStringParametersAsUnicode=true;encrypt=false;"
			accountsdb_url="jdbc:sqlserver://${DB_HOST};databasename=${accountsdb};sendStringParametersAsUnicode=true;encrypt=false;"
			reportsdb_url="jdbc:sqlserver://${DB_HOST};databasename=${reportsdb};sendStringParametersAsUnicode=true;encrypt=false;"
			admindb_url="jdbc:sqlserver://${DB_HOST};databasename=${admindb};sendStringParametersAsUnicode=true;encrypt=false;"
			kpnsdb_url="jdbc:sqlserver://${DB_HOST};databasename=${kpnsdb};user=${DB_USER};password=${DB_PASS};sendStringParametersAsUnicode=true;encrypt=false;"

		else

			authconfigdb_url="jdbc:sqlserver://${DB_HOST}:${DB_PORT};databasename=${idconfigdb};sendStringParametersAsUnicode=true;encrypt=false;"
			waasdb_url="jdbc:sqlserver://${DB_HOST}:${DB_PORT};databasename=${consoledb};sendStringParametersAsUnicode=true;encrypt=false;"
			accountsdb_url="jdbc:sqlserver://${DB_HOST}:${DB_PORT};databasename=${accountsdb};sendStringParametersAsUnicode=true;encrypt=false;"
			reportsdb_url="jdbc:sqlserver://${DB_HOST}:${DB_PORT};databasename=${reportsdb};sendStringParametersAsUnicode=true;encrypt=false;"
			admindb_url="jdbc:sqlserver://${DB_HOST}:${DB_PORT};databasename=${admindb};sendStringParametersAsUnicode=true;encrypt=false;"
			kpnsdb_url="jdbc:sqlserver://${DB_HOST}:${DB_PORT};databasename=${kpnsdb};user=${DB_USER};password=${DB_PASS};sendStringParametersAsUnicode=true;encrypt=false;"

		fi
	elif [ "${db_choice}" == "MYSQL" ]; then

		auth_db_datasource="com.mysql.cj.jdbc.MysqlDataSource"
		db_dialect="org.hibernate.dialect.MySQLDialect"
		auth_db_dialect=${db_dialect}
		admin_db_dialect="com.kony.console.admin.dialect.CustomMySQLDialect"
		kpns_db_dialect=${db_dialect}
		kpnsdb_defaultcatalog=${kpnsdb}
		kpns_db_delegate_class="org.quartz.impl.jdbcjobstore.StdJDBCDelegate"
		db_driver="com.mysql.cj.jdbc.Driver"
		db_validation_query="SELECT 1"
		metrics_module_name="com.mysql"
		if [[ "$IS_MYSQL_CONTAINER_REQUIRED" == "true" ]] ; then
		  DB_CONNECTION_PARAMS="?allowPublicKeyRetrieval=true&relaxAutoCommit=true&autoReconnect=true"
		  ADDITIONAL_DB_PARAM="&allowPublicKeyRetrieval=true"
	    else
          DB_CONNECTION_PARAMS="?relaxAutoCommit=true&autoReconnect=true"
	    fi

		if [ -z "${DB_PORT}" ]; then
			accountsdb_url="jdbc:mysql://${DB_HOST}/${accountsdb}?autoReconnect=true${ADDITIONAL_DB_PARAM}"
			reportsdb_url="jdbc:mysql://${DB_HOST}/${reportsdb}?autoReconnect=true${ADDITIONAL_DB_PARAM}"
			waasdb_url="jdbc:mysql://${DB_HOST}/${consoledb}?autoReconnect=true${ADDITIONAL_DB_PARAM}"
			authconfigdb_url="jdbc:mysql://${DB_HOST}/${idconfigdb}?autoReconnect=true&prepStmtCacheSize=400&prepStmtCacheSqlLimit=2048&readOnlyPropagatesToServer=false&cachePrepStmts=true&useLocalSessionState=true&useLocalTransactionState=true&rewriteBatchedStatements=true${ADDITIONAL_DB_PARAM}"
			admindb_url="jdbc:mysql://${DB_HOST}/${admindb}?autoReconnect=true${ADDITIONAL_DB_PARAM}"
			kpnsdb_url="jdbc:mysql://${DB_HOST}/${kpnsdb}?autoReconnect=true&useUnicode=yes&characterEncoding=UTF-8&cachePrepStmts=true&cacheCallableStmts=true&cacheServerConfiguration=true&useLocalSessionState=true&elideSetAutoCommits=true&alwaysSendSetIsolation=false&enableQueryTimeouts=false&rewriteBatchedStatements=true&max_allowed_packet=104857600${ADDITIONAL_DB_PARAM}"
		else
			accountsdb_url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${accountsdb}?autoReconnect=true${ADDITIONAL_DB_PARAM}"
			reportsdb_url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${reportsdb}?autoReconnect=true${ADDITIONAL_DB_PARAM}"
			waasdb_url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${consoledb}?autoReconnect=true${ADDITIONAL_DB_PARAM}"
			authconfigdb_url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${idconfigdb}?autoReconnect=true&prepStmtCacheSize=400&prepStmtCacheSqlLimit=2048&readOnlyPropagatesToServer=false&cachePrepStmts=true&useLocalSessionState=true&useLocalTransactionState=true&rewriteBatchedStatements=true${ADDITIONAL_DB_PARAM}"
			admindb_url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${admindb}?autoReconnect=true${ADDITIONAL_DB_PARAM}"
			kpnsdb_url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${kpnsdb}?autoReconnect=true&useUnicode=yes&characterEncoding=UTF-8&cachePrepStmts=true&cacheCallableStmts=true&cacheServerConfiguration=true&useLocalSessionState=true&elideSetAutoCommits=true&alwaysSendSetIsolation=false&enableQueryTimeouts=false&rewriteBatchedStatements=true&max_allowed_packet=104857600${ADDITIONAL_DB_PARAM}"
		fi
	elif [ "${db_choice}" == "ORACLE" ]; then

		auth_db_datasource="oracle.jdbc.pool.OracleDataSource"
		auth_db_dialect="org.hibernate.dialect.Oracle10gDialect"
		db_dialect="org.hibernate.dialect.Oracle10gDialect"
		admin_db_dialect="com.kony.console.admin.dialect.CustomOracleDialect"
		kpnsdb_defaultcatalog=""
		kpns_db_dialect=${db_dialect}
		db_driver="oracle.jdbc.driver.OracleDriver"
		db_validation_query="select 1 from dual"
		kpns_db_delegate_class="org.quartz.impl.jdbcjobstore.StdJDBCDelegate"

		if [ -z "${DB_PORT}" ]; then
			connection_url="jdbc:oracle:thin:@${DB_HOST}/${DB_SERVICE}"
		else
			connection_url="jdbc:oracle:thin:@${DB_HOST}:${DB_PORT}/${DB_SERVICE}"
		fi
		metrics_module_name="com.oracle"
		accountsdb_url="${connection_url}"
		reportsdb_url="${connection_url}"
		waasdb_url="${connection_url}"
		authconfigdb_url="${connection_url}"
		admindb_url="${connection_url}"
		kpnsdb_url="${connection_url}"
		auth_db_user=${idconfigdb}
		kpns_db_user=${kpnsdb}
		waas_db_user=${consoledb}
		reports_db_user=${reportsdb}
		admin_db_user=${admindb}
		accounts_db_user=${accountsdb}

	elif [ "${db_choice}" == "DB2" ]; then

		metrics_module_name="com.db2"
		db_dialect="org.hibernate.dialect.DB2Dialect"
		admin_db_dialect="com.kony.console.admin.dialect.CustomDB2Dialect"
		db_driver="com.ibm.db2.jcc.DB2Driver"
		db_validation_query="SELECT 1 FROM sysibm.sysdummy1"
		auth_db_dialect=${db_dialect}
		auth_db_datasource="com.ibm.db2.jcc.DB2DataSource"
		kpns_db_dialect="org.hibernate.dialect.DB2Dialect"
		kpns_db_delegate_class="org.quartz.impl.jdbcjobstore.StdJDBCDelegate"

		if [ -z "${DB_PORT}" ]; then
			authconfigdb_url="jdbc:db2://${DB_HOST}/${DB_INSTANCE}:currentSchema=${idconfigdb};"
			waasdb_url="jdbc:db2://${DB_HOST}/${DB_INSTANCE}:currentSchema=${consoledb};progressiveStreaming=2;"
			reportsdb_url="jdbc:db2://${DB_HOST}/${DB_INSTANCE}:currentSchema=${reportsdb};"
			accountsdb_url="jdbc:db2://${DB_HOST}/${DB_INSTANCE}:currentSchema=${accountsdb};"
			admindb_url="jdbc:db2://${DB_HOST}/${DB_INSTANCE}:currentSchema=${admindb};progressiveStreaming=2;"
			kpnsdb_url="jdbc:db2://${DB_HOST}/${DB_INSTANCE}:currentSchema=${kpnsdb};"
		else
			authconfigdb_url="jdbc:db2://${DB_HOST}:${DB_PORT}/${DB_INSTANCE}:currentSchema=${idconfigdb};"
			waasdb_url="jdbc:db2://${DB_HOST}:${DB_PORT}/${DB_INSTANCE}:currentSchema=${consoledb};progressiveStreaming=2;"
			reportsdb_url="jdbc:db2://${DB_HOST}:${DB_PORT}/${DB_INSTANCE}:currentSchema=${reportsdb};"
			accountsdb_url="jdbc:db2://${DB_HOST}:${DB_PORT}/${DB_INSTANCE}:currentSchema=${accountsdb};"
			admindb_url="jdbc:db2://${DB_HOST}:${DB_PORT}/${DB_INSTANCE}:currentSchema=${admindb};progressiveStreaming=2;"
			kpnsdb_url="jdbc:db2://${DB_HOST}:${DB_PORT}/${DB_INSTANCE}:currentSchema=${kpnsdb};progressiveStreaming=2;allowNextOnExhaustedResultSet=1;"
		fi
	fi
		
    if [ "$USE_EXISTING_DB" == "true" ]; then
		UPGRADE_PROPERTIES_FILE="$PREVIOUS_INSTALL_LOCATION"/upgrade.properties
		accounts_encryption_key=$( get_value "$UPGRADE_PROPERTIES_FILE" "ACCOUNTS_ENCRYPTION_KEY" )
		waas_master_key=$( get_value "$UPGRADE_PROPERTIES_FILE" "WAAS_MASTER_KEY" )
		waas_master_key_id=$( get_value "$UPGRADE_PROPERTIES_FILE" "WAAS_MASTER_KEY_ID" )
		auth_master_key=$( get_value "$UPGRADE_PROPERTIES_FILE" "AUTH_MASTER_KEY" )
		auth_master_key_id=$( get_value "$UPGRADE_PROPERTIES_FILE" "AUTH_MASTER_KEY_ID" )		
	elif [ "$USE_EXISTING_DB" == "false" ]; then
		accounts_encryption_key=$(generate_unique_guid)
		waas_master_key=$(generate_unique_guid)
		waas_master_key_id=$(generate_unique_guid)
		auth_master_key=$(generate_unique_guid)
		auth_master_key_id=$(generate_unique_guid)
	fi

	if [ "$COM_PROTOCOL" == "http" ]; then
		DEFAULT_INGRESS_PORT=80		
		IS_SECURE="false"
	elif [ "$COM_PROTOCOL" == "https" ]; then
		DEFAULT_INGRESS_PORT=443		
		IS_SECURE="true"
	fi
}

get_value() {
	declare -A CONFIG
	IFS="="
	while read -r key value
	do
		if [ -n $value ]; then
			CONFIG[$key]=$value
		fi
	done < $1
	unset IFS
	key=$2
	echo -e "${CONFIG[$key]}" | tr -d '[:space:]'
}

get_encrypted_value() {
	 java -cp "$LIB_DIR"/foundry-utils.jar com.kony.fabric.containers.util.EncryptInfo $1
}

encrypt_variables(){
	server_storage_db_pass=$DB_PASS
	server_storage_db_pass_secret_key=$DB_PASS_SECRET_KEY
	server_truststore_pass_secret=$(get_encrypted_value "changeit")
	server_jms_user_pass_secret=$(get_encrypted_value "admin")
}

generate_unique_guid(){
	od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
}

get_base_64_encoded_value() {
	echo -n $1 | base64 -w 0
}

replace_variables_in_file() {
eval "cat <<EOF
$(<"$1")
EOF
" > "$2"
}

validate_inputs_from_props_file() {
	[[ -z "$INSTALL_ENV_NAME" ]] && { log_error_and_exit "Installation Environment name cannot be empty"; }
	[[ -z "$FABRIC_BUILD_VERSION" ]] && { log_error_and_exit "The FABRIC_BUILD_VERSION input cannot be empty. Please provide a valid Foundry docker image version tag"; }
	[[ -z "$FABRIC_DATABASE_BUILD_VERSION" ]] && { log_error_and_exit "The FABRIC_DATABASE_BUILD_VERSION input cannot be empty. Please provide a valid Foundry database docker image version tag"; }
	[[ -z "$FABRIC_BUILD_TYPE" ]] && { log_error_and_exit "The FABRIC_BUILD_TYPE input cannot be empty. This should be set to either PRODUCTION or NON-PRODUCTION"; }
    if [[ "$SETUP_TYPE" == "kubernetes" && "$ALL_COMPONENTS_ENABLED" != "Y" && "$ALL_COMPONENTS_ENABLED" != "y" && "$ALL_COMPONENTS_ENABLED" != "N" && "$ALL_COMPONENTS_ENABLED" != "n" ]] ; then
	   log_error_and_exit "Invalid input for ALL_COMPONENTS_ENABLED. Set either Y or N."
	fi
	if [[ "$SETUP_TYPE" == "kubernetes" && "$ALL_COMPONENTS_ENABLED" != "Y" && "$ALL_COMPONENTS_ENABLED" != "y" ]] ; then
	   if [[ -z "$INTEGRATION_ENABLED" && -z "$IDENTITY_ENABLED" && -z "$MESSAGING_ENABLED" && -z "$CONSOLE_ENABLED" && -z "$APIPORTAL_ENABLED" ]] ; then
	      log_error_and_exit "No components selected. Please select components"
	   fi
	   if [[ "$IDENTITY_ENABLED" != "Y" && "$IDENTITY_ENABLED" != "y" && "$IDENTITY_ENABLED" != "N" && "$IDENTITY_ENABLED" != "n" && ! -z "$IDENTITY_ENABLED" ]] ; then
	      log_error_and_exit "Invalid input for IDENTITY_ENABLED. Set either Y or N."
	   fi
	   if [[ "$CONSOLE_ENABLED" != "Y" && "$CONSOLE_ENABLED" != "y" && "$CONSOLE_ENABLED" != "N" && "$CONSOLE_ENABLED" != "n" && ! -z "$CONSOLE_ENABLED" ]] ; then
	      log_error_and_exit "Invalid input for CONSOLE_ENABLED. Set either Y or N."
	   fi
	   if [[ "$APIPORTAL_ENABLED" != "Y" && "$APIPORTAL_ENABLED" != "y" && "$APIPORTAL_ENABLED" != "N" && "$APIPORTAL_ENABLED" != "n" && ! -z "$APIPORTAL_ENABLED" ]] ; then
	      log_error_and_exit "Invalid input for APIPORTAL_ENABLED. Set either Y or N."
	   fi
	   if [[ "$INTEGRATION_ENABLED" != "Y" && "$INTEGRATION_ENABLED" != "y" && "$INTEGRATION_ENABLED" != "N" && "$INTEGRATION_ENABLED" != "n" && ! -z "$INTEGRATION_ENABLED" ]] ; then
	      log_error_and_exit "Invalid input for INTEGRATION_ENABLED. Set either Y or N."
	   fi
	   if [[ "$MESSAGING_ENABLED" != "Y" && "$MESSAGING_ENABLED" != "y" && "$MESSAGING_ENABLED" != "N" && "$MESSAGING_ENABLED" != "n" && ! -z "$MESSAGING_ENABLED" ]] ; then
	      log_error_and_exit "Invalid input for MESSAGING_ENABLED. Set either Y or N."
	   fi
	   if [[ "$IDENTITY_ENABLED" != "Y" && "$IDENTITY_ENABLED" != "y" && "$MESSAGING_ENABLED" != "N" && "$CONSOLE_ENABLED" != "Y" && "$CONSOLE_ENABLED" != "y" && "$APIPORTAL_ENABLED" != "Y" && "$APIPORTAL_ENABLED" != "y" 
	       && "$INTEGRATION_ENABLED" != "Y" && "$INTEGRATION_ENABLED" != "y" && "$MESSAGING_ENABLED" != "Y" && "$MESSAGING_ENABLED" != "y" ]] ; then
	      log_error_and_exit "No components selected. Please select components"
	   fi
	fi
	if [ "$INSTALL_CHOICE" == "ONPREM_DEV" ]; then
		> /dev/null
		# https://stackoverflow.com/q/8185706/4452196
		# remove when the below two lines are uncommented

		if [ "$SETUP_TYPE" != "kubernetes" ]; then
			[[ -z "$SERVER_PORT" ]] && { log_error_and_exit "Server Port cannot be empty"; }
			! [[ $SERVER_PORT =~ $NUMBER_FORMAT ]] && { log_error_and_exit "Server port should be a number"; }
		fi
	fi

    [[ -z "$SERVER_DOMAIN_NAME" ]] && { log_error_and_exit "Domain name cannot be empty"; }
	
	if [[ "$COM_PROTOCOL" != "http" && "$COM_PROTOCOL" != "https" ]] ; then
		log_error_and_exit "Communication protocol is invalid. Please provide either HTTP or HTTPS."
	fi

	if [ "${COM_PROTOCOL}" == "https" ]; then
		if [ "$SETUP_TYPE" == "kubernetes" ]; then
			CERT_FILE_EXT=${HTTPS_CERT_FILE##*.}
			KEY_FILE_EXT=${HTTPS_KEY_FILE##*.}
			if [[ "$CERT_FILE_EXT" != "pem" || ! -f "$HTTPS_CERT_FILE" ]] ; then
				log_error_and_exit "Invalid Certificate. Please ensure an existing pem format certificate is provided.";
			fi

			if [[ "${KEY_FILE_EXT}" != "pem" || ! -f "$HTTPS_KEY_FILE" ]] ; then
				log_error_and_exit "Invalid Key file. Please ensure an existing pem format key file is provided. ";
			fi
		elif [ "$SETUP_TYPE" == "singleContainer" ]; then
			KEYSTORE_FILE_EXT=${KEYSTORE_FILE##*.}
			if [[ "$KEYSTORE_FILE_EXT" != "jks" || ! -f "$KEYSTORE_FILE" ]] ; then
				log_error_and_exit "Invalid Keystore File. Please ensure an existing jks format Keystore file is provided.";
			fi
			[[ -z "$KEYSTORE_FILE_PASS" ]] && { log_error_and_exit "HTTPS Keystore file password cannot be empty"; }
		fi

	fi

	[[ -z "$DB_TYPE" ]] && { log_error_and_exit "Database type cannot be empty"; }
	if [[ "$DB_TYPE" != "mysql" && "$DB_TYPE" != "mysqlcluster" && "$DB_TYPE" != "sqlserver" && "$DB_TYPE" != "oracle" && "$DB_TYPE" != "db2" ]] ; then
		log_error_and_exit "Database type is invalid"
	fi

	if [[ "$SETUP_TYPE" == "singleContainer" ]]; then
	[[ -z "$IS_MYSQL_CONTAINER_REQUIRED" ]] && { log_error_and_exit "MySQL container requirement can't be empty, please enter true/false"; }
	fi

	if [[ "$IS_MYSQL_CONTAINER_REQUIRED" == "false" || "$SETUP_TYPE" == "kubernetes" ]] ; then
		[[ -z "$DB_HOST" ]] && { log_error_and_exit "Database server hostname cannot be empty"; }
	    [[ ! -z "$DB_PORT" && ! $DB_PORT =~ $NUMBER_FORMAT ]] && { log_error_and_exit "Database server port should be a number"; }
	    [[ -z "$DB_USER" ]] && { log_error_and_exit "Database server user cannot be empty"; }
	fi

	[[ -z "$DB_PASS" ]] && { log_error_and_exit "Database server password cannot be empty"; }

	if [[ "$DB_TYPE" == "oracle" || "$DB_TYPE" == "db2" ]] ; then
		[[ -z "$DB_DATA_TS" ]] && { log_error_and_exit "Database Data tablespace name cannot be empty"; }
		[[ -z "$DB_INDEX_TS" ]] && { log_error_and_exit "Database Index tablespace name cannot be empty"; }
		[[ -z "$DB_LOB_TS" ]] && { log_error_and_exit "Database LOB tablespace name cannot be empty"; }
	fi

	if [[ "$DB_TYPE" == "oracle" ]]; then
		[[ -z "$DB_SERVICE" ]] && { log_error_and_exit "Database service name cannot be empty"; }
	fi

	if [[ "$DB_TYPE" == "db2" ]]; then
		[[ -z "$DB_INSTANCE" ]] && { log_error_and_exit "Database instance name cannot be empty"; }
	fi

    if [[ "$OWNER_REGISTRATION_REQUIRED" != "Y" && "$OWNER_REGISTRATION_REQUIRED" != "y" && "$OWNER_REGISTRATION_REQUIRED" != "N" && "$OWNER_REGISTRATION_REQUIRED" != "n" ]] ; then
	   log_error_and_exit "Invalid input for OWNER_REGISTRATION_REQUIRED. Set either Y or N."
	fi
	
	if [[ ( "${USE_EXISTING_DB}" != "Y" || "${USE_EXISTING_DB}" != "y" ) && ( "$OWNER_REGISTRATION_REQUIRED" == "Y" || "$OWNER_REGISTRATION_REQUIRED" == "y" ) ]]; then
		[[ -z "$OWNER_USER_ID" ]] && { log_error_and_exit "User email cannot be empty"; }
		[[ -z "$OWNER_PASSWORD" ]] && { log_error_and_exit "User password cannot be empty"; }
		[[ -z "$OWNER_FIRST_NAME" ]] && { log_error_and_exit "User first name cannot be empty"; }
		[[ -z "$OWNER_LAST_NAME" ]] && { log_error_and_exit "User last name cannot be empty"; }
		[[ -z "$OWNER_ENV_NAME" ]] && { log_error_and_exit "Environment name cannot be empty"; }
	fi

	if [[ "$SETUP_TYPE" == "kubernetes" && "$ALERTMANAGER_SETUP_REQUIRED" != "Y" && "$ALERTMANAGER_SETUP_REQUIRED" != "y" && "$ALERTMANAGER_SETUP_REQUIRED" != "N" && "$ALERTMANAGER_SETUP_REQUIRED" != "n" ]] ; then
	   log_error_and_exit "Invalid input for ALERTMANAGER_SETUP_REQUIRED. Set either Y or N."
	fi

	if [[ "$SETUP_TYPE" == "kubernetes" && ( "$ALERTMANAGER_SETUP_REQUIRED" == "Y" || "$ALERTMANAGER_SETUP_REQUIRED" == "y" ) ]]; then
		[[ -z "$SMTP_SMARTHOST" ]] && { log_error_and_exit "SMTP smarthost cannot be empty"; }
		[[ -z "$RECIPIENT_ADDRESS" ]] && { log_error_and_exit "Recipient address cannot be empty"; }
		[[ -z "$SENDER_ADDRESS" ]] && { log_error_and_exit "Sender address cannot be empty"; }
		[[ -z "$SENDER_PASSWORD" ]] && { log_error_and_exit "Sender authentication password cannot be empty"; }
	fi
}

component_selection_input() {
    PS3="$1:"
    options=("Y" "N")
	select opt in "${options[@]}"
	do
		case $opt in
			"Y")
				eval "$1"='Y'
				break
				;;
			"N")
				eval "$1"='N'
				break
				;;
			*) log_error "invalid option";;
		esac
	done
}

prompt_user_inputs() {
	echo Please enter following details
	decoratorLarge
	log_msg "Installation Details"
	decoratorSmall
	INSTALL_ENV_NAME=$(prompt_string 'Install Environment name')
	decoratorLarge
	log_msg "Foundry Docker image version you are planning to install/upgrade"
	decoratorSmall
	FABRIC_BUILD_VERSION=$(prompt_string 'Foundry Build version')
	FABRIC_DATABASE_BUILD_VERSION=$(prompt_string 'Flyway Build version')
	decoratorSmall
	log_msg "Set this to PRODUCTION for Production deployment. NON-PRODUCTION for DEV/QA or other non-production environments"
	FABRIC_BUILD_TYPE=$(prompt_string 'Foundry Build type')
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
		decoratorLarge
		log_msg "Install Components"
		decoratorSmall
		log_msg "Select Y/N, based on whether individual components or all are needed"
		component_selection_input ALL_COMPONENTS_ENABLED
		if [ "$ALL_COMPONENTS_ENABLED" != 'Y' ]; then
		   component_selection_input IDENTITY_ENABLED
		   component_selection_input CONSOLE_ENABLED
		   component_selection_input APIPORTAL_ENABLED
		   component_selection_input INTEGRATION_ENABLED
		   component_selection_input MESSAGING_ENABLED
		fi
		decoratorSmall
		log_msg "Components selected are:\nALL_COMPONENTS_ENABLED=$ALL_COMPONENTS_ENABLED\nIDENTITY_ENABLED=$IDENTITY_ENABLED\nCONSOLE_ENABLED=$CONSOLE_ENABLED\nAPIPORTAL_ENABLED=$APIPORTAL_ENABLED\nINTEGRATION_ENABLED=$INTEGRATION_ENABLED\nMESSAGING_ENABLED=$MESSAGING_ENABLED"
	fi
	decoratorLarge
	log_msg "Application Server Details"
	decoratorSmall
	SERVER_DOMAIN_NAME=$(prompt_string 'Domain Name')

	if [[ "$INSTALL_CHOICE" == 'ONPREM_DEV' && "$SETUP_TYPE" != "kubernetes" ]]; then 
		SERVER_PORT=$(prompt_number 'Server Port')
	fi

	PS3='Please select communication protocol: '
	protocols=("HTTP" "HTTPS")
	select opt in "${protocols[@]}"
	do
		case $opt in
			"HTTP")
				COM_PROTOCOL='http'
				break
				;;
			"HTTPS")
				COM_PROTOCOL='https'
				break
				;;
			*) log_error "invalid option";;
		esac
	done
	if [ "${COM_PROTOCOL}" == "https" ]; then
		if [ "$SETUP_TYPE" == 'kubernetes' ]; then
			HTTPS_CERT_FILE=$(prompt_cert_pem 'Certificate File Path')
			HTTPS_KEY_FILE=$(prompt_cert_pem 'Certificate Key File Path')
		elif [ "$SETUP_TYPE" == "singleContainer" ]; then
			KEYSTORE_FILE=$(prompt_cert_jks 'Keystore File Path')
			KEYSTORE_FILE_PASS=$(prompt_secret 'Keystore File password')
		fi
	fi

	decoratorLarge
	log_msg "Database details"
	decoratorSmall
	log_msg "Select database type"
	PS3='Please select database server: '
	options=("MySQL" "MySQLCluster" "SQLServer" "Oracle")
	select opt in "${options[@]}"
	do
		case $opt in
			"MySQL")
				DB_TYPE='mysql'
				break
				;;
      "MySQLCluster")
        DB_TYPE='mysqlcluster'
        break
        ;;
			"SQLServer")
				DB_TYPE='sqlserver'
				break
				;;
			"Oracle")
				DB_TYPE='oracle'
				break
				;;	
			*) log_error "invalid option";;
		esac
	done
	IS_MYSQL_CONTAINER_REQUIRED=$(prompt_string 'Is MySQL 8.0.31 container required')
	DB_HOST=$(prompt_string 'Database Hostname')
	DB_PORT=$(prompt_number 'Database Port')
	DB_USER=$(prompt_string 'Database Username')
	DB_PASS=$(prompt_secret 'Database Password')
	echo 'Enter incase of Encrypted Database Password'
	read -p "DB_PASS_SECRET_KEY: " DB_PASS_SECRET_KEY

	if [ "${DB_TYPE}" == "oracle" -o "${DB_TYPE}" == "db2" ]; then
		DB_DATA_TS=$(prompt_string 'Data Tablespace')
		DB_INDEX_TS=$(prompt_string 'Index Tablespace')
		DB_LOB_TS=$(prompt_string 'LOB Tablespace')
	fi

	if [ "${DB_TYPE}" == "oracle" ]; then
		DB_SERVICE=$(prompt_string 'Database Service Name')
	elif [ "${DB_TYPE}" == "db2" ]; then
		DB_INSTANCE=$(prompt_string 'Database Instance Name')
	fi

	DB_PREFIX=$(prompt_optional_string 'Database Prefix')
	DB_SUFFIX=$(prompt_optional_string 'Database Suffix')

	USE_EXISTING_DB=$(prompt_string 'Use existing databases from a previous Volt MX Foundry instance? (Y/N)')
	if [ "${USE_EXISTING_DB}" == "Y" -o "${USE_EXISTING_DB}" == "y" ]; then
		PREVIOUS_INSTALL_LOCATION=$(prompt_string 'Previous install artifact directory')	
	fi
	
	if [[ "${USE_EXISTING_DB}" != "Y" && "${USE_EXISTING_DB}" != "y" ]]; then
		decoratorLarge
	    log_msg 'Is Owner Registration Required?'
	    component_selection_input OWNER_REGISTRATION_REQUIRED
		if [ "$OWNER_REGISTRATION_REQUIRED" == "Y" ]; then
		    log_msg "Volt MX Foundry Account Registration Details"
			decoratorSmall
			OWNER_USER_ID=$(prompt_string 'User Id')
			OWNER_PASSWORD=$(prompt_secret 'Password')
			OWNER_FIRST_NAME=$(prompt_string 'First Name')
			OWNER_LAST_NAME=$(prompt_string 'Last Name')
			OWNER_ENV_NAME=$(prompt_string 'Environment Name')
			decoratorSmall
		fi
	fi

	if [ "$SETUP_TYPE" == 'kubernetes' ]; then
		decoratorLarge
		log_msg 'Is Alertmanager setup Required?'
	    component_selection_input ALERTMANAGER_SETUP_REQUIRED
		if [ "${ALERTMANAGER_SETUP_REQUIRED}" == "Y" -o "${ALERTMANAGER_SETUP_REQUIRED}" == "y" ]; then
			log_msg "Volt MX Foundry Alertmanager Configuration Details"
			decoratorSmall
		    SMTP_SMARTHOST=$(prompt_string 'SMTP Smarthost')
			RECIPIENT_ADDRESS=$(prompt_string 'Recipient Address')
			SENDER_ADDRESS=$(prompt_string 'Sender Address')
			SENDER_PASSWORD=$(prompt_secret 'Sender Password')
			decoratorSmall
		fi
	fi

}

# Prompts for string value for an optional input
# Usage: <var>=$(prompt_optional_string <prompt_label>)
# Ex: USER_NAME=$(prompt_optional_string 'Time Zone')
prompt_optional_string() {
	local INPUT_VAL=''
    read -p "$1: " INPUT_VAL

	echo $INPUT_VAL
}

# Prompts for string value, with retry prompt when no value given
# Usage: <var>=$(prompt_string <prompt_label>)
# Ex: USER_NAME=$(prompt_string 'Username')
prompt_string() {
    local INPUT_VAL=''
    read -p "$1: " INPUT_VAL

    while [ -z "$INPUT_VAL" ]
    do
        echo "Invalid '$1' value. Please enter correct value." 1>&2
        read -p "$1: " INPUT_VAL
    done

    echo $INPUT_VAL
}

# Prompts for certificate files of pem format, with retry prompt when no value given
# Usage: <var>=$(prompt_cert <prompt_label>)
# Ex: USER_PASS=$(prompt_root '/root/cert.pem')
prompt_cert_pem() {
    local INPUT_VAL=''			
    read -p "$1: " INPUT_VAL		
	CERT_EXT=${INPUT_VAL##*.}		
    while [[ ! "$CERT_EXT" == "pem" || ! -f "$INPUT_VAL" ]]		
    do		
        echo "Invalid '$1' value. Please provide an existing pem file." 1>&2		
		echo "$INPUT_VAL#*."		
        read -p "$1: " INPUT_VAL		
		CERT_EXT=${INPUT_VAL##*.}		
    done		
    echo $INPUT_VAL		
}

# Prompts for certificate files of jks format, with retry prompt when no value given
# Usage: <var>=$(prompt_cert <prompt_label>)
# Ex: USER_PASS=$(prompt_root '/root/cert.jks')
prompt_cert_jks() {
    local INPUT_VAL=''
    read -p "$1: " INPUT_VAL
	CERT_EXT=${INPUT_VAL##*.}
    while [[ ! "$CERT_EXT" == "jks" || ! -f "$INPUT_VAL" ]]
    do
        echo "Invalid '$1' value. Please provide an existing jks file." 1>&2
		echo "$INPUT_VAL#*."
        read -p "$1: " INPUT_VAL
		CERT_EXT=${INPUT_VAL##*.}
    done
    echo $INPUT_VAL
}


# Prompts for string values like passwords, with retry prompt when no value given
# Usage: <var>=$(prompt_secret <prompt_label>)
# Ex: USER_PASS=$(prompt_secret 'Password')
prompt_secret() {
    local INPUT_VAL=''
    read -sp "$1: " INPUT_VAL
    echo 1>&2

    while [ -z "$INPUT_VAL" ]
    do
        echo "Invalid '$1' value. Please enter correct value." 1>&2
        read -sp "$1: " INPUT_VAL
        echo 1>&2
    done

    echo $INPUT_VAL
}

# Prompts for number value, with retry prompt when no value or invalid number given
# Usage: <var>=$(prompt_number <prompt_label>)
# Ex: SERVER_PORT=$(prompt_number 'Server port')
prompt_number() {
    local INPUT_VAL=$(prompt_string "$1")

    while [[ ! "$INPUT_VAL" =~ $NUMBER_FORMAT ]]
    do
        echo "'$INPUT_VAL' is not a number. Please enter a valid number for '$1'." 1>&2
        INPUT_VAL=$(prompt_string "$1")
    done

    echo $INPUT_VAL
}

get_user_inputs() {
	# This value is to handle onprem installation
	# without affecting Cloud installation
	INSTALL_CHOICE=ONPREM_DEV

	if [ "$USER_INPUT_FILE" == "" ]; then
		prompt_user_inputs
	else
		log_msg "Loading user inputs from $USER_INPUT_FILE file..."
		load_inputs_from_props_file "$USER_INPUT_FILE"
		log_msg "Validating user inputs from $USER_INPUT_FILE file..."
		validate_inputs_from_props_file
	fi

	components_selected

	if [ "${OWNER_REGISTRATION_REQUIRED}" == "Y" -o "${OWNER_REGISTRATION_REQUIRED}" == "y" ]; then
		OWNER_REGISTRATION_REQUIRED="true"
	else
		OWNER_REGISTRATION_REQUIRED="false"
	fi
	
	# Setting default value for optional inputs
	TIME_ZONE=${TIME_ZONE:-"Etc/UTC"}
}

components_selected() {
    if [[ "$SETUP_TYPE" != "kubernetes" || "$ALL_COMPONENTS_ENABLED" == "Y" || "$ALL_COMPONENTS_ENABLED" == "y" ]] ; then
		IDENTITY_ENABLED=true;
		CONSOLE_ENABLED=true;
		APIPORTAL_ENABLED=true;
		INTEGRATION_ENABLED=true;
		MESSAGING_ENABLED=true;
	else
	    if [[ "$IDENTITY_ENABLED" == "Y" || "$IDENTITY_ENABLED" == "y" ]]; then
		   IDENTITY_ENABLED=true;
		else
		   IDENTITY_ENABLED=false;
		fi
		if [[ "$CONSOLE_ENABLED" == "Y" || "$CONSOLE_ENABLED" == "y" ]]; then
		   CONSOLE_ENABLED=true;
		else
		   CONSOLE_ENABLED=false;
		fi
		if [[ "$APIPORTAL_ENABLED" == "Y" || "$APIPORTAL_ENABLED" == "y" ]]; then
		   APIPORTAL_ENABLED=true;
		else
		   APIPORTAL_ENABLED=false;
		fi
		if [[ "$INTEGRATION_ENABLED" == "Y" || "$INTEGRATION_ENABLED" == "y" ]]; then
		   INTEGRATION_ENABLED=true;
		else
		   INTEGRATION_ENABLED=false;
		fi
		if [[ "$MESSAGING_ENABLED" == "Y" || "$MESSAGING_ENABLED" == "y" ]]; then
		   MESSAGING_ENABLED=true;
		else
		   MESSAGING_ENABLED=false;
		fi
	fi
}

create_install_environment_dir() {
	mkdir -p "$WORK_DIR/$INSTALL_ENV_NAME"
}

get_fabric_status(){
	publicURL=${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}
	java -cp "$LIB_DIR"/foundry-utils.jar com.kony.fabric.containers.action.FabricStartupCheck $publicURL $IDENTITY_ENABLED $CONSOLE_ENABLED $APIPORTAL_ENABLED $INTEGRATION_ENABLED $MESSAGING_ENABLED
}

wait_for_fabric_startup(){
	log_msg "Waiting for Volt MX Foundry server to start up..."
	sleep 300
	konyFabricStatus=$(get_fabric_status)
	konyFabricStatus=$(echo $konyFabricStatus | cut -d ' ' -f 10-)
	RETRY_COUNT=1
	MAX_RETRY_COUNT=10

	while [ "$konyFabricStatus" != "true" -a $RETRY_COUNT -le $MAX_RETRY_COUNT ]; do
		log_msg "Will wait for Volt MX Foundry server start up for 60 seconds..."
		sleep 60

		log_msg "Waiting for Volt MX Foundry server start up (retry attempt #$RETRY_COUNT of $MAX_RETRY_COUNT)"
		konyFabricStatus=$(get_fabric_status)
		konyFabricStatus=$(echo $konyFabricStatus | cut -d ' ' -f 10-)
		RETRY_COUNT=$((RETRY_COUNT + 1))
	done

	if [ "$konyFabricStatus" != "true" ]; then
		log_error_and_exit "Failed to setup environment. Foundry server startup is not complete."
	else
		log_msg "Foundry server startup complete."
	fi
}

do_auth_environment_registration(){
	log_msg "Owner Registering with given credentials..."

	auth_reg_post_url=${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/accounts/api/v1_0/accounts/config/onebox
	auth_reg_public_url="${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}"
	devportal_base_url="${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/apiportal"
	
	java -cp "$LIB_DIR"/foundry-utils.jar com.kony.fabric.containers.action.AutoRegistration $auth_reg_public_url \
		$OWNER_FIRST_NAME $OWNER_LAST_NAME $OWNER_USER_ID $OWNER_PASSWORD $OWNER_ENV_NAME $devportal_base_url $INTEGRATION_ENABLED $MESSAGING_ENABLED

	echo -e "\n"
}

print_install_end_notes() {
	echo -e "Volt MX Foundry cluster is created successfully.\n\nBelow are the App URLs:\n\n"
	if [ "$SETUP_TYPE" == "kubernetes" ]; then
		echo -e "Volt MX Foundry cluster is created successfully.\n\nBelow are the App URLs:\n\n" >> "${INSTALL_LOG_LOCATION}"
	fi

	if [ "$IDENTITY_ENABLED" == "true" ]; then
		echo -e "\tVolt MX Identity service: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/authService/"
		if [ "$SETUP_TYPE" == "kubernetes" ]; then
			echo -e "\tVolt MX Identity service: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/authService/" >> "${INSTALL_LOG_LOCATION}"
		fi
	fi
	if [ "$CONSOLE_ENABLED" == "true" ]; then
		echo -e "\tVolt MX Foundry console: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/mfconsole"
		if [ "$SETUP_TYPE" == "kubernetes" ]; then
			echo -e "\tVolt MX Foundry console: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/mfconsole" >> "${INSTALL_LOG_LOCATION}"
		fi
	fi
	if [ "$APIPORTAL_ENABLED" == "true" ]; then
		echo -e "\tVolt MX Developer API portal services: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/apiportal"
		if [ "$SETUP_TYPE" == "kubernetes" ]; then
			echo -e "\tVolt MX Developer API portal services: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/apiportal" >> "${INSTALL_LOG_LOCATION}"
		fi
	fi
	if [ "$INTEGRATION_ENABLED" == "true" ]; then
		echo -e "\tVolt MX Integration console: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/admin"
		if [ "$SETUP_TYPE" == "kubernetes" ]; then
			echo -e "\tVolt MX Integration console: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/admin" >> "${INSTALL_LOG_LOCATION}"
		fi
	fi
	if [ "$MESSAGING_ENABLED" == "true" ]; then
		echo -e "\tVolt MX Engagement console: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/kpns"
		if [ "$SETUP_TYPE" == "kubernetes" ]; then
			echo -e "\tVolt MX Engagement console: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/kpns" >> "${INSTALL_LOG_LOCATION}"
		fi
	fi

	# echo "Volt MX Foundry healthcheck URL: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/mfconsole/health_check/all"
	# echo "Volt MX Developer API portal services healthcheck URL: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/apiportal/healthcheck"
	# echo "Volt MX Integration console healthcheck URL: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/admin/healthcheck"
	# echo "Volt MX Integration services healthcheck URL: ${COM_PROTOCOL}://${SERVER_DOMAIN_NAME}:${SERVER_PORT}/services/healthcheck"
}


generate_upgrade_properties_file() {
	UPGRADE_PROPERTIES_FILE="$BASEDIR"/upgrade.properties
	if check_if_file_exists "$UPGRADE_PROPERTIES_FILE"; then
		rm "$UPGRADE_PROPERTIES_FILE"
	fi
	echo "ACCOUNTS_ENCRYPTION_KEY=${accounts_encryption_key}" >> "$UPGRADE_PROPERTIES_FILE"
	echo "WAAS_MASTER_KEY=${waas_master_key}" >> "$UPGRADE_PROPERTIES_FILE"
	echo "WAAS_MASTER_KEY_ID=${waas_master_key_id}" >> "$UPGRADE_PROPERTIES_FILE"
	echo "AUTH_MASTER_KEY=${auth_master_key}" >> "$UPGRADE_PROPERTIES_FILE"
	echo "AUTH_MASTER_KEY_ID=${auth_master_key_id}" >> "$UPGRADE_PROPERTIES_FILE"
}

install_packages(){	
	install_and_enable_docker
	
	cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
	setenforce 0
	sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
	yum install -y kubelet-${KUBELET_VERSION} kubeadm-${KUBEADM_VERSION} kubectl-${KUBECTL_VERSION} --disableexcludes=kubernetes > /dev/null
	systemctl enable --now kubelet
	
}

install_and_enable_docker(){
	if ! is_command_present docker; then
		log_msg 'Docker is required for installing the Volt MX Foundry Kubernetes solution.'
		log_msg "Installing docker packages..."
		install_docker
	fi	
	if [ $(is_service_running "docker") != "active" ];
	then
		log_msg "Starting docker service..."
		systemctl enable docker.service > /dev/null
		systemctl start docker.service > /dev/null
		sleep 10
	fi
}

install_docker(){
	yum install -y yum-utils \
		device-mapper-persistent-data \
		lvm2 > /dev/null
	yum-config-manager \
		--add-repo \
		https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
	yum install -y docker-ce-20.10.17 docker-ce-cli-20.10.17 containerd.io > /dev/null
	DOCKER_USER=$(sh -c 'echo $SUDO_USER')	
	if [ "$DOCKER_USER" != "" ];
	then
		log_msg "Configuration changes for running docker as non-root user"
		groupadd docker
		usermod -aG docker $DOCKER_USER
	fi	
}

is_service_running(){
	echo $(systemctl is-active $1)
}

copy_cni_plugins() {
	log_msg "Copying CNI plugins"
	mkdir -p /opt/cni/bin
	if [ "$(arch)" == "aarch64" ]; then
       cp $BASEDIR/resources/cni/bin/arm64/* /opt/cni/bin
	elif [ "$(arch)" == "x86_64" ]; then
	   cp $BASEDIR/resources/cni/bin/x64/* /opt/cni/bin
	fi
	chmod 777 /opt/cni/bin/*
}
