import 'package:flutter/material.dart';

// Define the primary color (Green from the image)
const Color primaryGreen = Color(0xFF1E88E5); 

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        // Makes the AppBar clear with white background
        
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
                   Image.asset('assets/icon2.png',
                    fit: BoxFit.contain,
                    ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                // Replace with your actual logo asset/icon
              
              ),
            ),
            const SizedBox(height: 30),

            // 2. Title
            const Text(
              'Join the Watch Party',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // 3. Subtitle
            const Text(
              'Log in or register to unlock your personal TV feed.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),

            // 4. Log In / Sign Up Segmented Control
            const ToggleButtonRow(),
            const SizedBox(height: 30),

            // 5. Form Fields
            // First Name and Last Name in a Row
          
            const SizedBox(height: 20),

            // Email Field
            const LabeledTextField(
              label: 'Email',
              hintText: 'johndoe@gmail.com',

              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            // Password Field
            const LabeledTextField(
              label: 'Set Password',
              hintText: '********',
              isPassword: true,
            ),
            const SizedBox(height: 30),

            // 6. Register Button
            Column(
              spacing: 10,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle registration logic
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1A8927),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                Text("Or With"),
                      SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle registration logic
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                         side: BorderSide(color: Colors.grey,width: 0.5)
                      
                      ),
                      elevation: 0,
                    ),
                    child:
                    Row(
                        spacing: 10,
                        mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/glogo.png'),
                          const Text(
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                      'Contiune With Google ',
                    
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        
                      ),
                    ),
                    
                      ],
                    ),
                   
                  ),
                ),
                  SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle registration logic
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                         side: BorderSide(color: Colors.grey,width: 0.5)
                      
                      ),
                      elevation: 0,
                    ),
                    child:
                    Row(
                        spacing: 10,
                        mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/apple.png'),
                          const Text(
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                      'Contiune With Apple ',
                    
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        
                      ),
                    ),
                    
                      ],
                    ),
                   
                  ),
                ),
                
                
              ],
            ),
            
          ],
        ),
      ),
    );
  }
}


// --- Helper Widgets ---

// Custom Widget for the Labeled Text Fields
class LabeledTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final bool isPassword;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          
          obscureText: isPassword,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey),
              
               // Hide default border
            ),
            filled: true,
            fillColor: Colors.white, // Light grey background
            // Show the visibility icon for password fields
            suffixIcon: isPassword 
                ? const Icon(Icons.link, color: Colors.grey)
                : null,
          ),
        ),
      ],
    );
  }
}

// Custom Widget for the Log In / Sign Up Toggle
class ToggleButtonRow extends StatelessWidget {
  const ToggleButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Light grey background
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          // Log In Button (Inactive)
        
          Expanded(child: 
          GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: 
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white, // Active button background
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                
                'Log In',
                style: TextStyle(
                 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            
          )
          ),
          // Sign Up Button (Active)
          Expanded(child: 
          GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/signup');
            },
            child: 
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.from(alpha: 0, red: 245, green: 246, blue: 249),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                
                'Sign Up',
                style: TextStyle(
                 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey.shade600
                ),
              ),
            ),
            
          )
          ),
        ],
      ),
    );
  }
}


// void main() {
//   runApp(const MaterialApp(home: SignUpScreen()));
// }