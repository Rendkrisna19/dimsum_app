import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:equatable/equatable.dart';

// ================= STATES =================
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final User user;
  final String role;
  final String? idToko; // Tambahan penting untuk Multi-Tenant

  AuthAuthenticated(this.user, this.role, this.idToko);

  @override
  List<Object?> get props => [user, role, idToko];
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// ================= EVENTS =================
abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}
class LoginRequested extends AuthEvent {
  final String email, password;
  LoginRequested(this.email, this.password);
}
class RegisterRequested extends AuthEvent {
  final String name, email, password;
  RegisterRequested(this.name, this.email, this.password);
}

// ================= BLOC LOGIC =================
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthBloc() : super(AuthInitial()) {
    
    // LOGIC REGISTER MANUAL
    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final cred = await _auth.createUserWithEmailAndPassword(email: event.email, password: event.password);
        
        // Pendaftar baru otomatis jadi customer, id_toko null
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'name': event.name,
          'email': event.email,
          'role': 'customer', 
          'id_toko': null, 
        });
        
        emit(AuthAuthenticated(cred.user!, 'customer', null));
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    // LOGIC LOGIN MANUAL
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final cred = await _auth.signInWithEmailAndPassword(email: event.email, password: event.password);
        
        // Ambil data user, termasuk role dan id_toko
        final doc = await _firestore.collection('users').doc(cred.user!.uid).get();
        final data = doc.data();
        
        final role = data?['role'] ?? 'customer';
        final idToko = data?['id_toko']; 
        
        emit(AuthAuthenticated(cred.user!, role, idToko));
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });
  }
}