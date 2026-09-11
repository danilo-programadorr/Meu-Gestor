import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_consent.dart';

/// Persiste somente o aceite remoto próprio, sem contexto financeiro ou texto.
final class FirebaseAssistantRemoteConsentRepository
    implements AssistantRemoteConsentRepository {
  FirebaseAssistantRemoteConsentRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<bool> readOwnConsent({required String ownerId}) async {
    _validateOwnerId(ownerId);
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('assistantSettings')
          .doc('remote')
          .get(const GetOptions(source: Source.server));
      final Map<String, dynamic>? data = snapshot.data();
      return snapshot.exists && _isValidAllowedConsent(data);
    } on Object {
      return false;
    }
  }

  @override
  Future<void> setOwnConsent({
    required String ownerId,
    required bool financialContextAllowed,
  }) {
    _validateOwnerId(ownerId);
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('assistantSettings')
        .doc('remote')
        .set(<String, Object>{
          'consentVersion': AssistantRemoteConsent.version,
          'financialContextAllowed': financialContextAllowed,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Valida a forma fechada recebida do servidor antes de refletir o aceite.
  bool _isValidAllowedConsent(Map<String, dynamic>? data) {
    if (data == null ||
        data.keys.toSet().length != 3 ||
        !data.keys.toSet().containsAll(<String>[
          'consentVersion',
          'financialContextAllowed',
          'updatedAt',
        ])) {
      return false;
    }
    return data['consentVersion'] == AssistantRemoteConsent.version &&
        data['financialContextAllowed'] == true &&
        data['updatedAt'] is Timestamp;
  }

  void _validateOwnerId(String ownerId) {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId');
    }
  }
}
