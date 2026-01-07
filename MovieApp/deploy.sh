set -euo pipefail

echo "===== DEPLOY SCRIPT FOR HW2 - JAVA MOVIES APP ====="

 
SUBSCRIPTION_ID="9040ef74-edec-4353-9108-0bc24bad9587"

RESOURCE_GROUP="rg-moviesapp-hw2"
LOCATION="polandcentral"

PLAN_NAME="plan-moviesapp-hw2"
WEBAPP_NAME="movies-briana-hw2"

SQL_SERVER_NAME="sqlmoviesbriana-hw2"
DB_NAME="moviesdb_hw2"

ADMIN_USER="adminuser"
ADMIN_PASS="Parola123!"

 
# Selectare subscription
if [ -n "${SUBSCRIPTION_ID:-}" ]; then
  echo ">>> Setting subscription to $SUBSCRIPTION_ID"
  az account set --subscription "$SUBSCRIPTION_ID"
else
  echo ">>> SUBSCRIPTION_ID not set, using current default subscription."
fi

 
# Crare Resource Group
echo ">>> Creating resource group (if needed)..."
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"
else
  echo "Resource group $RESOURCE_GROUP already exists, skipping."
fi

 
# Creare App Service Plan (Linux)
echo ">>> Creating App Service Plan (if needed)..."
if ! az appservice plan show --name "$PLAN_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  az appservice plan create \
    --name "$PLAN_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --sku B1 \
    --is-linux
else
  echo "App Service Plan $PLAN_NAME already exists, skipping."
fi

 
# Creare Web App (Java 17)
echo ">>> Creating Web App (if needed)..."
if ! az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  az webapp create \
    --name "$WEBAPP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$PLAN_NAME" \
    --runtime "JAVA:17-java17"
else
  echo "Web App $WEBAPP_NAME already exists, skipping."
fi

 
# Creare SQL Server + Database
echo ">>> Creating SQL Server (if needed)..."
if ! az sql server show --name "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  az sql server create \
    --name "$SQL_SERVER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --admin-user "$ADMIN_USER" \
    --admin-password "$ADMIN_PASS"
else
  echo "SQL Server $SQL_SERVER_NAME already exists, skipping."
fi

echo ">>> Creating SQL Database (if needed)..."
if ! az sql db show --name "$DB_NAME" --server "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  az sql db create \
    --name "$DB_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --server "$SQL_SERVER_NAME" \
    --service-objective S0
else
  echo "SQL DB $DB_NAME already exists, skipping."
fi

 
# Configurare firewall SQL:
#    - stergere AllowAllAzureIps
#    - adaugare doar IP-urile Web App-ului
echo ">>> Configuring SQL firewall rules..."

# Stergere regula default daca exista
az sql server firewall-rule delete \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER_NAME" \
  --name "AllowAllWindowsAzureIps" \
  &>/dev/null || true

az sql server firewall-rule delete \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER_NAME" \
  --name "AllowAllAzureIps" \
  &>/dev/null || true

# Ia outbound IP-urile webapp-ului
OUTBOUND_IPS=$(az webapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME" \
  --query outboundIpAddresses -o tsv)

echo "Outbound IPs for $WEBAPP_NAME: $OUTBOUND_IPS"

for ip in $(echo "$OUTBOUND_IPS" | tr "," " "); do
  echo "Adding firewall rule for IP $ip ..."
  az sql server firewall-rule create \
    --resource-group "$RESOURCE_GROUP" \
    --server "$SQL_SERVER_NAME" \
    --name "app-ip-$ip" \
    --start-ip-address "$ip" \
    --end-ip-address "$ip" \
    >/dev/null
done

 
# Build aplicatie (Maven)
echo ">>> Building application with Maven..."
mvn clean package -DskipTests

JAR_PATH=$(ls target/*.jar | head -n 1)
echo "JAR built at: $JAR_PATH"

 
# Setare Application Settings pentru DB
echo ">>> Setting app settings on Web App..."

CONN_STR="jdbc:sqlserver://$SQL_SERVER_NAME.database.windows.net:1433;database=$DB_NAME;encrypt=true;trustServerCertificate=false;loginTimeout=30;"

az webapp config appsettings set \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME" \
  --settings \
  "AZURE_SQL_CONNECTIONSTRING=$CONN_STR" \
  "DB_USERNAME=$ADMIN_USER" \
  "DB_PASSWORD=$ADMIN_PASS" \
  >/dev/null

 
# Deploy JAR in App Service
echo ">>> Deploying JAR to Web App..."
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME" \
  --type jar \
  --src-path "$JAR_PATH"

echo "===== DEPLOY COMPLETE ====="
echo "App URL:"
echo "  https://$WEBAPP_NAME.polandcentral-01.azurewebsites.net/"
