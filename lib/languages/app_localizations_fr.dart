const Map<String, String> localizedStringsFr = {
  'welcome': 'Bienvenue sur ShareHaven!',
  'version': 'Version',
  'welcoming_description': 'Votre compagnon de portefeuille Bitcoin.',

  // Settings
  'language': 'Sélectionner la langue',
  'currency': 'Sélectionner la devise',
  'settings': 'Paramètres',
  'settings_message':
      'Personnalisez vos paramètres globaux pour une meilleure expérience.',
  'reset_settings': 'Réinitialiser les paramètres',
  'reset_settings_scaffold': 'Paramètres réinitialisés par défaut!',
  'reset_app': 'Réinitialiser l\'application',

  // Network
  'network_banner': 'Réseau Testnet',

  // PIN Setup & Verification
  'enter_pin': 'Entrer le code PIN',
  'enter_6_digits_pin': 'Entrez votre code PIN à 6 chiffres',
  'confirm_pin': 'Confirmer le code PIN',
  'pin_mismatch': 'Le code PIN ne correspond pas',
  'pin_must_be_six': 'Le code PIN doit comporter 6 chiffres',
  'pin_set_success': 'Code PIN défini avec succès!',
  'pin_verified': 'Code PIN vérifié avec succès!',
  'pin_incorrect': 'Code PIN incorrect. Essayez à nouveau.',
  'verify_pin': 'Vérifier le code PIN',
  'success': 'succès',
  'confirm': 'Confirmer',
  're_enter_pin': 'Saisissez à nouveau votre code PIN',

  // Wallet
  'personal_wallet': 'Portefeuille personnel',
  'shared_wallet': 'Portefeuille partagé',
  'ca_wallet': 'Portefeuille CA',
  'edit_alias': 'Modifier l\'alias',
  'pub_key': 'Clé publique',
  'address': 'Adresse',
  'transactions': 'Transactions',
  'wallet_creation': 'Création de portefeuille',
  'backup_your_wallet': 'Sauvegardez votre portefeuille',
  'wallet_backed_up': 'Portefeuille sauvegardé avec succès!',
  'wallet_not_backed_up':
      'Échec de la sauvegarde du portefeuille. Essayez à nouveau.',
  'confirm_wallet_deletion':
      'Êtes-vous sûr de vouloir supprimer ce portefeuille?',
  'current_height': 'Hauteur actuelle du bloc',
  'timestamp': 'Horodatage',
  'multisig_tx': 'Transactions MultiSig',
  'no_transactions_to_sign': 'Aucune transaction à signer',
  'receive_bitcoin': 'Recevoir des Bitcoins',

  // Transactions & Blockchain
  'fetching_balance': 'Récupération du solde...',
  'balance': 'Solde',
  'pending_balance': 'Solde en attente',
  'confirmed_balance': 'Solde confirmé',
  'transaction_history': 'Historique des transactions',
  'transaction_sent': 'Transaction envoyée',
  'transaction_failed': 'Échec de la transaction',
  'broadcasting_error': 'Erreur de diffusion',
  'transaction_fee': 'Frais de transaction',
  'sending_transaction': 'Envoi de la transaction...',
  'transaction_success': 'Transaction diffusée avec succès!',
  'transaction_failed_retry': 'Échec de la transaction. Veuillez réessayer.',
  'internal': 'Interne',
  'sent': 'Envoyé',
  'received': 'Reçu',
  'to': 'À',
  'from': 'De',
  'fee': 'Frais',
  'amount': 'Montant',
  'transaction_details': 'Détails de la transaction',
  'internal_tx': 'Transaction interne',
  'sent_tx': 'Transaction envoyée',
  'received_tx': 'Transaction reçue',
  'senders': 'Expéditeurs',
  'receivers': 'Destinataires',
  'confirmation_details': 'Détails de confirmation',
  'status': 'Statut',
  'confirmed_block': 'Confirmé au bloc',
  'mempool': 'Visiter le Mempool',

// Erreurs et Avertissements
  'error_invalid_address': 'Format d’adresse invalide',
  'error_wallet_creation':
      'Erreur lors de la création du portefeuille avec le descripteur fourni',
  'error_loading_data': 'Erreur lors du chargement des données du portefeuille',
  'error_network': 'Erreur réseau. Veuillez vérifier votre connexion.',
  'error_insufficient_funds':
      'Fonds confirmés insuffisants. Veuillez attendre la confirmation de vos transactions.',
  'error_wallet_locked':
      'Le portefeuille est verrouillé. Veuillez entrer votre code PIN.',
  'error_wallet_not_found': 'Portefeuille introuvable.',
  'invalid_address': 'Adresse invalide',
  'invalid_psbt': 'PSBT invalide',
  'error_older': 'Erreur : Cette valeur Older existe déjà !',
  'invalid_descriptor': 'Veuillez entrer un descripteur valide',
  'invalid_mnemonic': 'Phrase mnémonique invalide. Vérifiez et réessayez.',
  'threshold_missing': 'Seuil manquant',
  'public_keys_missing': 'Clés publiques manquantes',
  'your_public_key_missing': 'Votre clé publique n’est pas incluse',
  'descriptor_name_missing': 'Nom du descripteur manquant',
  'descriptor_name_exists': 'Le nom du descripteur existe déjà',
  'error_validating_descriptor': 'Erreur lors de la validation du descripteur',
  'recipient_address_required': 'Veuillez entrer une adresse de destinataire.',
  'invalid_descriptor_status': 'Descripteur invalide - ',
  'error_wallet_descriptor':
      'Erreur lors de la création du portefeuille avec le descripteur fourni',
  'error_public_key_not_contained':
      'Erreur : Votre clé publique n’est pas contenue dans ce descripteur',
  'spending_path_required': 'Veuillez sélectionner un chemin de dépense',
  'generic_error': 'Erreur',
  'both_fields_required': 'Les deux champs sont obligatoires',
  'pub_key_exists': 'Cette clé publique existe déjà',
  'alias_exists': 'Cet alias existe déjà',
  'correct_errors': 'Veuillez corriger les erreurs et réessayer',

  // Interface d'Envoi/Signature
  'sending_menu': 'Menu d\'Envoi',
  'signing_menu': 'Menu de Signature',
  'recipient_address': 'Adresse du Destinataire',
  'enter_rec_addr': 'Entrez l\'Adresse du Destinataire',
  'psbt': 'PSBT',
  'enter_psbt': 'Entrez PSBT',
  'enter_amount_sats': 'Entrez le Montant (Sats)',
  'keys': 'Clés',
  'blocks': 'Blocs',
  'use_available_balance': 'Utiliser le Solde Disponible',
  'select_spending_path': 'Sélectionner le Chemin de Dépense',

// File (Fichier)
  'storage_permission_needed':
      'L’autorisation de stockage est requise pour enregistrer le fichier',
  'file_already_exists': 'Le fichier existe déjà',
  'file_save_prompt':
      'Un fichier portant le même nom existe déjà. Voulez-vous l’enregistrer quand même?',
  'file_saved': 'Fichier enregistré dans',
  'file_uploaded': 'Fichier téléchargé avec succès',
  'failed_upload': 'Échec du téléchargement du fichier',

// Scaffold Messenger (Messages d’alerte)
  'copy_to_clipboard': 'Copier dans le presse-papiers',
  'mnemonic_clipboard': 'Phrase mnémonique copiée dans le presse-papiers',
  'pub_key_clipboard': 'Clé publique copiée dans le presse-papiers',
  'address_clipboard': 'Adresse copiée dans le presse-papiers',
  'descriptor_clipboard': 'Descripteur copié dans le presse-papiers',
  'psbt_clipboard': 'PSBT copié dans le presse-papiers',
  'transaction_created': 'Transaction créée avec succès',
  'transaction_signed': 'Transaction signée avec succès',
  'timelock_condition_removed':
      'Condition de verrouillage temporel ({x}) supprimée',
  'alias_removed': 'supprimé',
  'multisig_updated': 'Multisig mis à jour avec succès',
  'timelock_updated':
      'Condition de verrouillage temporel mise à jour avec succès',

// Private Data (Données Privées)
  'private_data': 'Données privées',
  'saved_mnemonic': 'Voici votre phrase mnémonique enregistrée',
  'saved_descriptor': 'Voici votre descripteur enregistré',
  'saved_pub_key': 'Voici votre clé publique enregistrée',
  'download_descriptor': 'Télécharger le descripteur',

// Buttons (Boutons)
  'close': 'Fermer',
  'save': 'Enregistrer',
  'cancel': 'Annuler',
  'set_pin': 'Définir le PIN',
  'reset': 'Réinitialiser',
  'submit': 'Soumettre',

// Spending Summary (Résumé des dépenses)
  'spending_summary': 'Résumé des dépenses',
  'type': 'Type',
  'threshold': 'Seuil',
  'transaction_info': 'Informations sur la transaction',
  'can_be_spent': 'peut être dépensé!',
  'unconfirmed': 'Non confirmé',
  'no_transactions_available': 'Aucune transaction disponible',
  'value': 'Valeur',

// Spending Paths (Chemins de dépenses)
  'immediately_spend': 'Vous ({x}) pouvez immédiatement dépenser',
  'cannot_spend': 'Vous ({x}) ne pouvez pas dépenser de sats pour le moment',
  'threshold_required':
      '\n\nUn seuil de {x} sur {y} est requis. \nVous devez vous coordonner avec ces clés',
  'spend_alone':
      '\nVous pouvez dépenser seul. \nCes autres clés peuvent également dépenser indépendamment: ',
  'spend_together': '\nVous devez dépenser avec: ',
  'total_unconfirmed': 'Total non confirmé: {x} sats',
  'time_remaining_text': 'Temps restant',
  'blocks_remaining': 'Blocs restants',
  'time_remaining': '{x} heures, {y} minutes, {z} secondes',
  'sats_available': 'sats disponibles dans',
  'future_sats': 'les sats seront disponibles à l’avenir',
  'upcoming_funds': 'Fonds à venir - Appuyez sur ⋮ pour plus de détails',
  'spending_paths_available': 'Chemins de dépenses disponibles',
  'no_spending_paths_available': 'Aucun chemin de dépenses disponible',

// Synchronisation
  'no_updates_yet': '⏳ Pas encore de mises à jour ! Réessayez plus tard. 🔄',
  'new_block_transactions_detected':
      '🚀 Nouveau bloc et transactions détectés ! Synchronisation en cours... 🔄',
  'new_block_detected':
      '📦 Nouveau bloc détecté ! Synchronisation en cours... ⛓️',
  'new_transaction_detected':
      '₿ Nouvelle transaction détectée ! Synchronisation en cours... 🔄',
  'no_internet': '🚫 Pas d’Internet ! Connectez-vous et réessayez.',
  'syncing_wallet': '🔄 Synchronisation du portefeuille… Veuillez patienter.',
  'syncing_complete': '✅ Synchronisation terminée !',
  'syncing_error': '⚠️ Oups ! Quelque chose s’est mal passé.\nErreur',

  // Importer Portefeuille
  'import_wallet': 'Importer un Portefeuille Partagé',
  'descriptor': 'Descripteur',
  'generate_public_key': 'Générer une Clé Publique',
  'select_file': 'Sélectionner un Fichier',
  'valid': 'Le descripteur est valide',
  'aliases_and_pubkeys': 'Alias et Clés Publiques',
  'alias': 'Alias',
  'navigating_wallet': 'Navigation vers votre portefeuille',
  'loading': 'Chargement...',
  'idle_ready_import': 'Inactif - Prêt à importer',
  'descriptor_valid_proceed':
      'Le descripteur est valide - Vous pouvez continuer',

  // Créer un Portefeuille Partagé
  'create_shared_wallet': 'Créer un Portefeuille Partagé',
  'descriptor_name': 'Nom du Descripteur',
  'enter_descriptor_name': 'Entrez le Nom du Descripteur',
  'enter_public_keys_multisig': 'Entrez les Clés Publiques pour Multisig',
  'enter_timelock_conditions': 'Entrez les Conditions de Verrouillage Temporel',
  'older': 'Ancien',
  'pub_keys': 'Clés Publiques',
  'create_descriptor': 'Créer un Descripteur',
  'edit_public_key': 'Modifier la Clé Publique',
  'add_public_key': 'Ajouter une Clé Publique',
  'enter_pub_key': 'Entrez la Clé Publique',
  'enter_alias': 'Entrez le Nom de l\'Alias',
  'edit_timelock': 'Modifier la Condition de Verrouillage Temporel',
  'add_timelock': 'Ajouter une Condition de Verrouillage Temporel',
  'enter_older': 'Entrez la Valeur Ancienne',
  'descriptor_created': 'Descripteur {x} Créé',
  'conditions': 'Conditions',
  'aliases': 'Alias',

// Créer ou Restaurer un Portefeuille Unique
  'create_restore': 'Créer ou Restaurer un Portefeuille',
  'new_mnemonic': 'Nouveau mnémonique généré !',
  'wallet_loaded': 'Portefeuille chargé avec succès !',
  'wallet_created': 'Portefeuille créé avec succès !',
  'creating_wallet': 'Création du portefeuille en cours...',
  'enter_mnemonic': 'Entrez le Mnémonique',
  'enter_12': 'Entrez ici votre mnémonique de 12 mots',
  'create_wallet': 'Créer un Portefeuille',
  'generate_mnemonic': 'Générer un Mnémonique',

  // Divers
  'select_currency': 'Sélectionner la devise',
  'select_language': 'Sélectionner la langue',
  'enable_tutorial': 'Activer le tutoriel',
  'disable_tutorial': 'Désactiver le tutoriel',
  'resetting_app': 'Réinitialisation de l’application...',
  'app_reset_success': 'L’application a été réinitialisée.',
  'confirm_reset': 'Êtes-vous sûr de vouloir réinitialiser?',
  'confirm_exit': 'Êtes-vous sûr de vouloir quitter?',
  'import_wallet_descriptor': 'Importer le descripteur du portefeuille',
  'edit_wallet_name': 'Modifier le nom du portefeuille',
  'descriptor_cannot_be_empty': 'Le descripteur ne peut pas être vide',
  'descriptor_valid': 'Le descripteur est valide',
  'navigate_wallet': 'Naviguer vers le portefeuille',
  'public_keys_with_alias': 'Clés publiques avec alias',
  'create_import_message':
      'Gérez vos portefeuilles Bitcoin partagés en toute simplicité ! Que vous créiez un nouveau portefeuille ou en importiez un existant, nous sommes là pour vous aider.',
  'yes': 'Oui'
};
