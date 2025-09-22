enum UserRole { 
  patient, 
  family;
  
  @override
  String toString() {
    switch (this) {
      case UserRole.patient:
        return 'patient';
      case UserRole.family:
        return 'family';
    }
  }
}