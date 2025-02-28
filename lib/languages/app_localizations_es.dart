const Map<String, String> localizedStringsEs = {
  'welcome': '¡Bienvenido a ShareHaven!',
  'version': 'Versión',
  'welcoming_description': 'Tu compañero de billetera Bitcoin.',

  // Settings
  'language': 'Seleccionar idioma',
  'currency': 'Seleccionar moneda',
  'settings': 'Configuración',
  'settings_message':
      'Personaliza la configuración global para mejorar tu experiencia.',
  'reset_settings': 'Restablecer configuración predeterminada',
  'reset_settings_scaffold':
      '¡Configuración restablecida a los valores predeterminados!',
  'reset_app': 'Restablecer aplicación',

  // Network
  'network_banner': 'Red Testnet',

  // PIN Setup & Verification
  'enter_pin': 'Ingresar PIN',
  'enter_6_digits_pin': 'Ingresa tu PIN de 6 dígitos',
  'confirm_pin': 'Confirmar PIN',
  'pin_mismatch': 'El PIN no coincide',
  'pin_must_be_six': 'El PIN debe tener 6 dígitos',
  'pin_set_success': '¡PIN configurado con éxito!',
  'pin_verified': '¡PIN verificado con éxito!',
  'pin_incorrect': 'PIN incorrecto. Inténtalo de nuevo.',
  'verify_pin': 'Verificar PIN',
  'success': 'Éxito',
  'confirm': 'Confirmar',
  're_enter_pin': 'Vuelva a ingresar su PIN',

  // Wallet
  'personal_wallet': 'Billetera personal',
  'shared_wallet': 'Billetera compartida',
  'ca_wallet': 'Billetera CA',
  'edit_alias': 'Editar alias',
  'pub_key': 'Clave pública',
  'address': 'Dirección',
  'transactions': 'Transacciones',
  'wallet_creation': 'Creación de billetera',
  'backup_your_wallet': 'Respalda tu billetera',
  'wallet_backed_up': '¡Billetera respaldada con éxito!',
  'wallet_not_backed_up':
      'Error al respaldar la billetera. Inténtalo de nuevo.',
  'confirm_wallet_deletion':
      '¿Estás seguro de que quieres eliminar esta billetera?',
  'current_height': 'Altura actual del bloque',
  'timestamp': 'Marca de tiempo',
  'multisig_tx': 'Transacciones MultiSig',
  'no_transactions_to_sign': 'No hay transacciones para firmar',
  'receive_bitcoin': 'Recibir Bitcoin',

  // Transactions & Blockchain
  'fetching_balance': 'Obteniendo saldo...',
  'balance': 'Saldo',
  'pending_balance': 'Saldo pendiente',
  'confirmed_balance': 'Saldo confirmado',
  'transaction_history': 'Historial de transacciones',
  'transaction_sent': 'Transacción enviada',
  'transaction_failed': 'Transacción fallida',
  'broadcasting_error': 'Error de transmisión',
  'transaction_fee': 'Tarifa de transacción',
  'sending_transaction': 'Enviando transacción...',
  'transaction_success': '¡Transacción enviada con éxito!',
  'transaction_failed_retry': 'Error en la transacción. Inténtalo de nuevo.',
  'internal': 'Interno',
  'sent': 'Enviado',
  'received': 'Recibido',
  'to': 'A',
  'from': 'De',
  'fee': 'Tarifa',
  'amount': 'Monto',
  'transaction_details': 'Detalles de la transacción',
  'internal_tx': 'Transacción interna',
  'sent_tx': 'Transacción enviada',
  'received_tx': 'Transacción recibida',
  'senders': 'Remitentes',
  'receivers': 'Destinatarios',
  'confirmation_details': 'Detalles de confirmación',
  'status': 'Estado',
  'confirmed_block': 'Confirmado en el bloque',
  'mempool': 'Visitar el Mempool',

// Errores y Advertencias
  'error_invalid_address': 'Formato de dirección inválido',
  'error_wallet_creation':
      'Error al crear la billetera con el descriptor proporcionado',
  'error_loading_data': 'Error al cargar los datos de la billetera',
  'error_network': 'Error de red. Por favor, verifica tu conexión.',
  'error_insufficient_funds':
      'Fondos confirmados insuficientes. Espera a que se confirmen tus transacciones.',
  'error_wallet_locked': 'La billetera está bloqueada. Ingresa tu PIN.',
  'error_wallet_not_found': 'Billetera no encontrada.',
  'invalid_address': 'Dirección inválida',
  'invalid_psbt': 'PSBT inválido',
  'error_older': 'Error: Este valor de Antigüedad ya existe!',
  'invalid_descriptor': 'Por favor, ingresa un descriptor válido',
  'invalid_mnemonic':
      'Frase mnemotécnica inválida. Verifica e inténtalo de nuevo.',
  'threshold_missing': 'Falta el umbral',
  'public_keys_missing': 'Faltan claves públicas',
  'your_public_key_missing': 'Tu clave pública no está incluida',
  'descriptor_name_missing': 'Falta el nombre del descriptor',
  'descriptor_name_exists': 'El nombre del descriptor ya existe',
  'error_validating_descriptor': 'Error al validar el descriptor',
  'recipient_address_required':
      'Por favor, ingresa una dirección de destinatario.',
  'invalid_descriptor_status': 'Descriptor inválido - ',
  'error_wallet_descriptor':
      'Error al crear la billetera con el descriptor proporcionado',
  'error_public_key_not_contained':
      'Error: Tu clave pública no está contenida en este descriptor',
  'spending_path_required': 'Por favor, selecciona una ruta de gasto',
  'generic_error': 'Error',
  'both_fields_required': 'Ambos campos son obligatorios',
  'pub_key_exists': 'Esta clave pública ya existe',
  'alias_exists': 'Este alias ya existe',
  'correct_errors': 'Por favor, corrija los errores e inténtelo de nuevo',

  // Interfaz de Envío/Firma
  'sending_menu': 'Menú de Envío',
  'signing_menu': 'Menú de Firma',
  'recipient_address': 'Dirección del Destinatario',
  'enter_rec_addr': 'Ingrese la Dirección del Destinatario',
  'psbt': 'PSBT',
  'enter_psbt': 'Ingrese PSBT',
  'enter_amount_sats': 'Ingrese el Monto (Sats)',
  'keys': 'Llaves',
  'blocks': 'Bloques',
  'use_available_balance': 'Usar Saldo Disponible',
  'select_spending_path': 'Seleccionar Ruta de Gasto',
  'psbt_created': 'PSBT Creado',
  'spending_path': 'Ruta de Gasto',
  'signers': 'Firmantes',
  'confirm_transaction': '¿Quieres firmar esta transacción?',
  'psbt_not_finalized':
      'Este PSBT aún no está finalizado, ¡compártelo con los otros usuarios!',

// File (Archivo)
  'storage_permission_needed':
      'Se requiere permiso de almacenamiento para guardar el archivo',
  'file_already_exists': 'El archivo ya existe',
  'file_save_prompt':
      'Ya existe un archivo con el mismo nombre. ¿Quieres guardarlo de todos modos?',
  'file_saved': 'Archivo guardado en',
  'file_uploaded': 'Archivo subido con éxito',
  'failed_upload': 'Error al subir el archivo',

// Scaffold Messenger (Mensajes emergentes)
  'copy_to_clipboard': 'Copiar al portapapeles',
  'mnemonic_clipboard': 'Frase mnemotécnica copiada al portapapeles',
  'pub_key_clipboard': 'Clave pública copiada al portapapeles',
  'address_clipboard': 'Dirección copiada al portapapeles',
  'descriptor_clipboard': 'Descriptor copiado al portapapeles',
  'psbt_clipboard': 'PSBT copiado al portapapeles',
  'transaction_created': 'Transacción creada con éxito',
  'transaction_signed': 'Transacción firmada con éxito',
  'timelock_condition_removed':
      'Condición de bloqueo de tiempo ({x}) eliminada',
  'alias_removed': 'eliminado',
  'multisig_updated': 'Multisig actualizado con éxito',
  'timelock_updated': 'Condición de bloqueo de tiempo actualizada con éxito',

// Private Data (Datos privados)
  'private_data': 'Datos privados',
  'saved_mnemonic': 'Aquí está tu frase mnemotécnica guardada',
  'saved_descriptor': 'Aquí está tu descriptor guardado',
  'saved_pub_key': 'Aquí está tu clave pública guardada',
  'download_descriptor': 'Descargar descriptor',

// Buttons (Botones)
  'close': 'Cerrar',
  'save': 'Guardar',
  'cancel': 'Cancelar',
  'set_pin': 'Establecer PIN',
  'reset': 'Restablecer',
  'submit': 'Enviar',
  'add': 'Agregar',
  'copy': 'Copiar',
  'share': 'Compartir',
  'sign': 'Firmar',
  'yes': 'Sí',
  'no': 'No',
  'decode': 'Decodifica',

// Spending Summary (Resumen de gastos)
  'spending_summary': 'Resumen de gastos',
  'type': 'Tipo',
  'threshold': 'Umbral',
  'transaction_info': 'Información de la transacción',
  'can_be_spent': 'puede ser gastado!',
  'unconfirmed': 'No confirmado',
  'no_transactions_available': 'No hay transacciones disponibles',
  'value': 'Valor',

// Spending Paths (Rutas de gasto)
  'immediately_spend': 'Tú ({x}) puedes gastar inmediatamente',
  'cannot_spend': 'Tú ({x}) no puedes gastar sats en este momento',
  'threshold_required':
      '\n\nSe requiere un umbral de {x} de {y}. \nDebes coordinarte con estas claves',
  'spend_alone':
      '\nPuedes gastar solo. \nEstas otras claves también pueden gastar independientemente: ',
  'spend_together': '\nDebes gastar junto con: ',
  'total_unconfirmed': 'Total no confirmado: {x} sats',
  'time_remaining_text': 'Tiempo restante',
  'blocks_remaining': 'Bloques restantes',
  'time_remaining': '{x} horas, {y} minutos, {z} segundos',
  'sats_available': 'sats disponibles en',
  'future_sats': 'los sats estarán disponibles en el futuro',
  'upcoming_funds': 'Fondos próximos - Pulsa ⋮ para más detalles',
  'spending_paths_available': 'Rutas de gasto disponibles',
  'no_spending_paths_available': 'No hay rutas de gasto disponibles',

  // Syncing
  'no_updates_yet':
      '⏳ ¡No hay actualizaciones todavía! Inténtalo más tarde. 🔄',
  'new_block_transactions_detected':
      '🚀 ¡Nuevo bloque y transacciones detectadas! Sincronizando ahora... 🔄',
  'new_block_detected': '📦 ¡Nuevo bloque detectado! Sincronizando ahora... ⛓️',
  'new_transaction_detected':
      '₿ ¡Nueva transacción detectada! Sincronizando ahora... 🔄',
  'no_internet': '🚫 ¡Sin conexión a Internet! Conéctate e intenta de nuevo.',
  'syncing_wallet': '🔄 Sincronizando billetera… Por favor, espera.',
  'syncing_complete': '✅ ¡Sincronización completa!',
  'syncing_error': '⚠️ ¡Ups! Algo salió mal.\nError',

  // Importar Billetera
  'import_wallet': 'Importar Billetera Compartida',
  'descriptor': 'Descriptor',
  'generate_public_key': 'Generar Clave Pública',
  'select_file': 'Seleccionar Archivo',
  'valid': 'El descriptor es válido',
  'aliases_and_pubkeys': 'Alias y Claves Públicas',
  'alias': 'Alias',
  'navigating_wallet': 'Navegando a tu billetera',
  'loading': 'Cargando...',
  'idle_ready_import': 'Inactivo - Listo para Importar',
  'descriptor_valid_proceed': 'El descriptor es válido - Puedes proceder',

// Crear Billetera Compartida
  'create_shared_wallet': 'Crear Billetera Compartida',
  'descriptor_name': 'Nombre del Descriptor',
  'enter_descriptor_name': 'Ingrese el Nombre del Descriptor',
  'enter_public_keys_multisig': 'Ingrese Claves Públicas para Multisig',
  'enter_timelock_conditions': 'Ingrese Condiciones de Bloqueo Temporal',
  'older': 'Antiguo',
  'pub_keys': 'Claves Públicas',
  'create_descriptor': 'Crear Descriptor',
  'edit_public_key': 'Editar Clave Pública',
  'add_public_key': 'Agregar Clave Pública',
  'enter_pub_key': 'Ingrese Clave Pública',
  'enter_alias': 'Ingrese Nombre del Alias',
  'edit_timelock': 'Editar Condición de Bloqueo Temporal',
  'add_timelock': 'Agregar Condición de Bloqueo Temporal',
  'enter_older': 'Ingrese Valor de Antigüedad',
  'descriptor_created': 'Descriptor {x} Creado',
  'conditions': 'Condiciones',
  'aliases': 'Alias',

  // Crear o Restaurar Billetera Única
  'create_restore': 'Crear o Restaurar Billetera',
  'new_mnemonic': '¡Nuevo mnemónico generado!',
  'wallet_loaded': '¡Billetera cargada con éxito!',
  'wallet_created': '¡Billetera creada con éxito!',
  'creating_wallet': 'Creando billetera...',
  'enter_mnemonic': 'Ingrese Mnemónico',
  'enter_12': 'Ingrese aquí su mnemónico de 12 palabras',
  'create_wallet': 'Crear Billetera',
  'generate_mnemonic': 'Generar Mnemónico',

  // Misceláneos
  'select_currency': 'Seleccionar moneda',
  'select_language': 'Seleccionar idioma',
  'enable_tutorial': 'Habilitar tutorial',
  'disable_tutorial': 'Deshabilitar tutorial',
  'resetting_app': 'Restableciendo la aplicación...',
  'app_reset_success': 'La aplicación ha sido restablecida.',
  'confirm_reset': '¿Estás seguro de que quieres restablecer?',
  'confirm_exit': '¿Estás seguro de que quieres salir?',
  'import_wallet_descriptor': 'Importar descriptor de billetera',
  'edit_wallet_name': 'Editar nombre de la billetera',
  'descriptor_cannot_be_empty': 'El descriptor no puede estar vacío',
  'descriptor_valid': 'El descriptor es válido',
  'navigate_wallet': 'Navegar a la billetera',
  'public_keys_with_alias': 'Claves públicas con alias',
  'create_import_message':
      '¡Gestiona tus billeteras compartidas de Bitcoin con facilidad! Ya sea creando una nueva billetera o importando una existente, estamos aquí para ayudarte.',
  'setting_wallet': 'Configurando tu monedero...',
  'morning_check': "🌅 ¡Buenos días! ¡Es hora de actualizar!",
  'afternoon_check': "🌞 ¡Revisión de la tarde! ¡Dale una actualización!",
  'night_check': "🌙 ¿Refresco nocturno? ¡Por qué no!",
  'processing': 'Procesando...'
};
