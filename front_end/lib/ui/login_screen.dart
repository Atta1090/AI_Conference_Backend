/*import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _passwordController = TextEditingController(); // ✅ rename
  final _confirmPassword = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;

  String? _error;

  static const Color _brandGreen = Color(0xFF3FA534);

  @override
  void dispose() {
    _email.dispose();
    _passwordController.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // ================= VALIDATION =================

  String? _validateEmail(String? v) {
    if ((v ?? '').isEmpty) return 'Email required';
    if (!v!.contains('@')) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').length < 6) return 'Min 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (_isLogin) return null;
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ================= SUBMIT =================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _passwordController.text,
        );
      }

      //widget.onLoginSuccess?.call();
      Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (_) =>  MainDashboard()),
);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLogin ? _loginUI() : _signupUI();
  }

  // ================= LOGIN =================

  Widget _loginUI() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 40),
                const Center(
                  child: Text(
                    "Welcome Back",
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 30),

                _field("Email", Icons.email, _email),

                const SizedBox(height: 15),

                _passwordField(), // ✅ fixed

                const SizedBox(height: 10),

                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: _brandGreen,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v!),
                    ),
                    const Text("Remember me"),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        if (_email.text.isEmpty) {
                          setState(() => _error = "Enter email first");
                          return;
                        }
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(
                                email: _email.text.trim());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Reset email sent")),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: _brandGreen),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Login"),
                ),

                const SizedBox(height: 25),

                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR LOGIN WITH"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _icon(Icons.g_mobiledata, Colors.red),
                    const SizedBox(width: 20),
                    _icon(Icons.facebook, Colors.blue),
                    const SizedBox(width: 20),
                    _icon(Icons.apple, Colors.black),
                  ],
                ),

                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _isLogin = false),
                    child: const Text("Don't have account? Sign Up"),
                  ),
                ),

                if (_error != null)
                  Text(_error!,
                      style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= SIGNUP =================

  Widget _signupUI() {
    return Scaffold(
      backgroundColor: _brandGreen,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _isLogin = true),
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white),
                  ),
                  const Text(
                    "Create Account",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Sign up to continue",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _field("Full Name", Icons.person, null),
                      const SizedBox(height: 12),
                      _field("Email", Icons.email, _email),
                      const SizedBox(height: 12),
                      _field("Phone", Icons.phone, null),
                      const SizedBox(height: 12),
                      _passwordField(),
                      const SizedBox(height: 12),
                      _confirmPasswordField(),

                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v!),
                            activeColor: _brandGreen,
                          ),
                          const Expanded(
                            child: Text(
                                "I agree to Terms & Privacy Policy"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandGreen,
                          minimumSize:
                              const Size(double.infinity, 50),
                        ),
                        child: const Text("Create Account"),
                      ),

                      Center(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _isLogin = true),
                          child: const Text(
                              "Already have account? Login"),
                        ),
                      ),

                      if (_error != null)
                        Text(_error!,
                            style:
                                const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ================= COMMON =================

  Widget _field(String hint, IconData icon,
      TextEditingController? controller) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: controller,
        validator: hint == "Email" ? _validateEmail : null,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: _validatePassword,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(_obscurePassword
                ? Icons.visibility_off
                : Icons.visibility),
          ),
        ),
      ),
    );
  }

  Widget _confirmPasswordField() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: _confirmPassword,
        obscureText: _obscureConfirmPassword,
        validator: _validateConfirmPassword,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Confirm Password",
          prefixIcon: Icon(Icons.lock),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, Color color) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      child: Icon(icon, color: color),
    );
  }
}*/



/*import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _passwordController = TextEditingController(); 
  final _confirmPassword = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;

  String? _error;

  static const Color _brandGreen = Color(0xFF3FA534);

  @override
  void dispose() {
    _email.dispose();
    _passwordController.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // ================= VALIDATION =================

  String? _validateEmail(String? v) {
    if ((v ?? '').isEmpty) return 'Email required';
    if (!v!.contains('@')) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').length < 6) return 'Min 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (_isLogin) return null;
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ================= SUBMIT =================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLogin ? _loginUI() : _signupUI();
  }

  // ================= LOGIN UI =================

  Widget _loginUI() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 20),
                
                // ✅ Logo Image Added Here
                Center(
                  child: Image.asset(
                    'assets/login_c.png', 
                    height: 120, // Aap size adjust kar sakte hain
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.image_not_supported, size: 50, color: Colors.grey);
                    },
                  ),
                ),

                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "Welcome Back",
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 30),

                _field("Email", Icons.email, _email),
                const SizedBox(height: 15),
                _passwordField(),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: _brandGreen,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v!),
                    ),
                    const Text("Remember me"),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        if (_email.text.isEmpty) {
                          setState(() => _error = "Enter email first");
                          return;
                        }
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(
                                email: _email.text.trim());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Reset email sent")),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: _brandGreen),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 10),

                _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: _brandGreen))
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandGreen,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),

                const SizedBox(height: 25),

                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR LOGIN WITH"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _icon(Icons.g_mobiledata, Colors.red),
                    const SizedBox(width: 20),
                    _icon(Icons.facebook, Colors.blue),
                    const SizedBox(width: 20),
                    _icon(Icons.apple, Colors.black),
                  ],
                ),

                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _isLogin = false),
                    child: const Text("Don't have account? Sign Up"),
                  ),
                ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= SIGNUP UI =================

  Widget _signupUI() {
    return Scaffold(
      backgroundColor: _brandGreen,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _isLogin = true),
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white),
                  ),
                  const Text(
                    "Create Account",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Sign up to continue",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _field("Full Name", Icons.person, null),
                      const SizedBox(height: 12),
                      _field("Email", Icons.email, _email),
                      const SizedBox(height: 12),
                      _field("Phone", Icons.phone, null),
                      const SizedBox(height: 12),
                      _passwordField(),
                      const SizedBox(height: 12),
                      _confirmPasswordField(),

                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v!),
                            activeColor: _brandGreen,
                          ),
                          const Expanded(
                            child: Text(
                                "I agree to Terms & Privacy Policy"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: _brandGreen))
                      : ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            minimumSize:
                                const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Create Account", style: TextStyle(color: Colors.white)),
                        ),

                      Center(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _isLogin = true),
                          child: const Text(
                              "Already have account? Login"),
                        ),
                      ),

                      if (_error != null)
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ================= COMMON WIDGETS =================

  Widget _field(String hint, IconData icon,
      TextEditingController? controller) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ]
      ),
      child: TextFormField(
        controller: controller,
        validator: hint == "Email" ? _validateEmail : null,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ]
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: _validatePassword,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(_obscurePassword
                ? Icons.visibility_off
                : Icons.visibility),
          ),
        ),
      ),
    );
  }

  Widget _confirmPasswordField() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ]
      ),
      child: TextFormField(
        controller: _confirmPassword,
        obscureText: _obscureConfirmPassword,
        validator: _validateConfirmPassword,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Confirm Password",
          prefixIcon: Icon(Icons.lock),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, Color color) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      child: Icon(icon, color: color),
    );
  }
}*/



import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _passwordController = TextEditingController(); 
  final _confirmPassword = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;

  String? _error;

  static const Color _brandGreen = Color(0xFF3FA534);
  // ✅ Humne background white rakha hai taake aapki PNG image merge ho jaye
  static const Color _pageBgColor = Colors.white; 

  @override
  void dispose() {
    _email.dispose();
    _passwordController.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // ================= VALIDATION =================

  String? _validateEmail(String? v) {
    if ((v ?? '').isEmpty) return 'Email required';
    if (!v!.contains('@')) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').length < 6) return 'Min 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (_isLogin) return null;
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ================= SUBMIT =================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    final nameCtrl = TextEditingController(text: 'Guest');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join as Guest'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Display name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      await cred.user?.updateDisplayName(name);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLogin ? _loginUI() : _signupUI();
  }

  // ================= LOGIN UI =================

  Widget _loginUI() {
    return Scaffold(
      backgroundColor: _pageBgColor, // ✅ Logo ke background se match karne ke liye
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 20),
                
                // ✅ Logo Image (Now merges with background)
                Center(
                  child: Image.asset(
                    'assets/login_c.png', 
                    height: 120, 
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.image_not_supported, size: 50, color: Colors.grey);
                    },
                  ),
                ),

                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "Welcome Back",
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 30),

                _field("Email", Icons.email, _email),
                const SizedBox(height: 15),
                _passwordField(),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: _brandGreen,
                      onChanged: (v) => setState(() => _rememberMe = v!),
                    ),
                    const Text("Remember me"),
                    const Spacer(),
                    TextButton(
                      onPressed: () {}, 
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: _brandGreen),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 10),

                _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: _brandGreen))
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandGreen,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: _isLoading ? null : _continueAsGuest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandGreen,
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: _brandGreen),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Continue as Guest"),
                ),

                const SizedBox(height: 25),

                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR LOGIN WITH"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _icon(Icons.g_mobiledata, Colors.red),
                    const SizedBox(width: 20),
                    _icon(Icons.facebook, Colors.blue),
                    const SizedBox(width: 20),
                    _icon(Icons.apple, Colors.black),
                  ],
                ),

                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isLogin = false),
                    child: const Text("Don't have account? Sign Up"),
                  ),
                ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= SIGNUP UI =================

  Widget _signupUI() {
    return Scaffold(
      backgroundColor: _brandGreen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // ✅ Left Align elements
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // ✅ Text and Arrow to the Left
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _isLogin = true),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Create Account",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Sign up to continue",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: const BoxDecoration(
                  color: _pageBgColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _field("Full Name", Icons.person, null),
                      const SizedBox(height: 15),
                      _field("Email", Icons.email, _email),
                      const SizedBox(height: 15),
                      _field("Phone", Icons.phone, null),
                      const SizedBox(height: 15),
                      _passwordField(),
                      const SizedBox(height: 15),
                      _confirmPasswordField(),

                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v!),
                            activeColor: _brandGreen,
                          ),
                          const Expanded(
                            child: Text("I agree to Terms & Privacy Policy"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: _brandGreen))
                      : ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Create Account", style: TextStyle(color: Colors.white)),
                        ),

                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _isLogin = true),
                          child: const Text("Already have account? Login"),
                        ),
                      ),

                      if (_error != null)
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ================= COMMON WIDGETS =================

  Widget _field(String hint, IconData icon, TextEditingController? controller) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // Slightly off-white for contrast
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        validator: hint == "Email" ? _validateEmail : null,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: _validatePassword,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock, color: Colors.grey),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _confirmPasswordField() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: _confirmPassword,
        obscureText: _obscureConfirmPassword,
        validator: _validateConfirmPassword,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Confirm Password",
          prefixIcon: Icon(Icons.lock, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}