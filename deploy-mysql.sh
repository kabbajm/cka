#!/bin/bash

# Choisir l'environnement : dev, staging, prod
ENV=${1}

if [[ -z "$ENV" ]]; then
  echo "Usage: ./deploy-mysql.sh [dev|staging|prod]"
  exit 1
fi

# Définir les mots de passe spécifiques à chaque env
case "$ENV" in
  dev)
    ROOT_PWD="devroot"
    USER_PWD="devpwd"
    ;;
  staging)
    ROOT_PWD="stagingroot"
    USER_PWD="stagingpwd"
    ;;
  prod)
    ROOT_PWD="prodroot"
    USER_PWD="prodpwd"
    ;;
  *)
    echo "Environnement invalide. Utilise : dev | staging | prod"
    exit 1
    ;;
esac

echo "📦 Déploiement dans l'environnement : $ENV"
echo "🔐 (Re)création du Secret mysql-secret..."

# Supprimer le Secret existant s'il existe
kubectl delete secret mysql-secret --ignore-not-found

# Créer le Secret avec les bonnes valeurs
kubectl create secret generic mysql-secret \
  --from-literal=MYSQL_ROOT_PASSWORD="$ROOT_PWD" \
  --from-literal=MYSQL_PASSWORD="$USER_PWD"

# Appliquer Kustomize
kubectl apply -k overlays/$ENV

echo "✅ Déploiement terminé pour l'environnement $ENV"
