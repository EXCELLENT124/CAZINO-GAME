enum FicaStatus { notStarted, pending, demoSubmitted, verified, rejected }

class Address {
  const Address({required this.line1, required this.city, required this.province,
    required this.postalCode, required this.country, this.line2 = ''});
  final String line1, line2, city, province, postalCode, country;
}

class FicaDocument {
  const FicaDocument({required this.type, required this.fileName,
    required this.uploadedAt, this.remoteReference});
  final String type, fileName;
  final DateTime uploadedAt;
  final String? remoteReference;
}

class PlayerAccount {
  const PlayerAccount({required this.id, required this.firstName,
    required this.lastName, required this.email, required this.phone,
    required this.idNumber, required this.dateOfBirth, required this.address,
    this.ficaStatus = FicaStatus.notStarted, this.documents = const []});
  final String id, firstName, lastName, email, phone, idNumber;
  final DateTime dateOfBirth;
  final Address address;
  final FicaStatus ficaStatus;
  final List<FicaDocument> documents;
  String get displayName => '$firstName $lastName';
}

class Challenge {
  const Challenge({required this.id, required this.fromPlayerId,
    required this.toPlayerId, this.accepted = false});
  final String id, fromPlayerId, toPlayerId;
  final bool accepted;
}

class ChatMessage {
  const ChatMessage({required this.id, required this.senderId,
    required this.text, required this.sentAt});
  final String id, senderId, text;
  final DateTime sentAt;
}
