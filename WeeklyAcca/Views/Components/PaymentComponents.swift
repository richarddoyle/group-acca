import SwiftUI
import UIKit

struct PaymentModuleSection: View {
    let amount: Double
    let recipientName: String
    let recipientPhone: String?
    let onPay: () -> Void
    let onManual: () -> Void
    
    @State private var showingNoPhoneAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stake Payment Required")
                        .font(.headline)
                    Text("Pay \(recipientName) to confirm your entry")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(amount, format: .currency(code: "GBP"))
                    .font(.title3.bold())
            }
            
            Button {
                if let phone = recipientPhone {
                    openMessages(to: phone)
                    // We don't call onPay() here anymore so the module stays visible
                } else {
                    showingNoPhoneAlert = true
                }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Pay with Apple Cash")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .alert("Missing Admin Info", isPresented: $showingNoPhoneAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(recipientName) hasn't set their phone number in their profile yet, so we can't send the payment message.")
            }
            
            Button {
                onManual()
            } label: {
                Text("I've Sent Payment")
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func openMessages(to phone: String) {
        let message = "Here is my \(amount.formatted(.currency(code: "GBP"))) stake for the Acca! ⚽️"
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "sms:\(phone)&body=\(encodedMessage)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    VStack {
        PaymentModuleSection(amount: 10.0, recipientName: "Rich", recipientPhone: "07123456789", onPay: {}, onManual: {})
            .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
}
