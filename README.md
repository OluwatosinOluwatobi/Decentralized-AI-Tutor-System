Democratizing quality education through blockchain technology and AI-driven personalized learning

## 📖 Overview

The Decentralized AI Tutor System is a revolutionary blockchain-based educational platform that delivers personalized learning experiences while storing credentials and achievements on-chain. Built on the Stacks blockchain using Clarity smart contracts, it combines the power of decentralized technology with adaptive AI-driven content delivery.

## ✨ Features

### 🎯 Core Learning System
- **📚 Learning Modules**: Create and manage educational content with difficulty levels and subject categorization
- **🔀 Module Forking**: Enable educators to fork existing modules for customization and adaptation
- **🔄 Ownership Transfer**: Allow creators to transfer module ownership to other users for collaboration or delegation
- **📊 Progress Tracking**: Real-time learning progress monitoring with completion percentages and scoring
- **🏆 Achievement System**: Automatic credential issuance upon module completion
- **🎖️ NFT Badges**: Earn digital badges (Gold, Silver, Bronze) based on performance scores
- **🔗 Module Prerequisites**: Define optional prerequisites for structured learning paths and sequential mastery

### 🏛️ Decentralized Governance
- **🗳️ Teacher DAO**: Democratic curriculum updates through proposal and voting system
- **📋 Proposal Management**: Create and vote on educational content proposals
- **⏰ Time-bound Voting**: Structured voting periods for fair decision-making

### 💰 Content Creation Incentives
- **🎯 Bounty System**: Reward creators for developing content in underserved languages
- **🌐 Language Diversity**: Promote educational content in multiple languages
- **💎 Creator Rewards**: Incentivize high-quality educational content creation

### 👥 Referral Rewards System
- **🤝 User Referrals**: Earn reputation points by referring new users to the platform
- **⭐ Reputation Boosts**: Both referrer and referee receive reputation increases upon successful registration
- **📈 Engagement Incentives**: Promote community growth through gamified referral mechanics

## 🛠️ Smart Contract Functions

```clarity
(register-user user-type referrer)  ; Register with optional referrer for rewards
(get-referral-count user)           ; Get number of successful referrals
```
### User Management
```clarity
(register-user "student")    ; Register as student or teacher
(get-user principal)         ; Retrieve user information
```

### Learning Modules
```clarity
(create-learning-module title description difficulty subject language prerequisite)
(fork-learning-module original-module-id new-title new-description new-difficulty new-subject new-language new-prerequisite)
(transfer-module-ownership module-id new-owner)
(enroll-in-module module-id)
(update-progress module-id progress-percent score)
(get-learning-module module-id)
```

### Credentials & Badges
```clarity
(get-credential credential-id)
(get-nft-badge user module-id)
```

### DAO Governance
```clarity
(create-dao-proposal title description type voting-duration)
(vote-on-proposal proposal-id vote-for)
(get-dao-proposal proposal-id)
```

### Bounty System
```clarity
(create-content-bounty title description language subject reward deadline)
(claim-bounty bounty-id)
(complete-bounty bounty-id content-uri)
```

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) (for testing)
- Stacks wallet for mainnet deployment

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Decentralized-AI-Tutor-System
   cd Decentralized-AI-Tutor-System
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Run tests**
   ```bash
   clarinet test
   ```

### 📝 Usage Examples

#### 1. Register as a Student
```clarity
(contract-call? .Decentralized-AI-Tutor-System register-user "student")
```

#### 2. Create a Learning Module (Teachers)
```clarity
(contract-call? .Decentralized-AI-Tutor-System create-learning-module
  "Introduction to Blockchain"
  "Learn the fundamentals of blockchain technology"
  u1
  "Technology"
  "English"
  none)  ; No prerequisite
```

#### 2.2 Fork an Existing Module
```clarity
(contract-call? .Decentralized-AI-Tutor-System fork-learning-module
  u1
  "Advanced Blockchain Concepts"
  "Deep dive into advanced blockchain topics"
  u3
  "Technology"
  "English"
  (some u2))  ; Prerequisite: module ID 2
```

#### 2.3 Transfer Module Ownership
```clarity
(contract-call? .Decentralized-AI-Tutor-System transfer-module-ownership u1 new-owner-principal)
```

#### 2.1 Create a Module with Prerequisite
```clarity
(contract-call? .Decentralized-AI-Tutor-System create-learning-module
  "Advanced Blockchain"
  "Deep dive into consensus mechanisms"
  u3
  "Technology"
  "English"
  (some u1))  ; Prerequisite: module ID 1
```

#### 3. Enroll in a Module
```clarity
(contract-call? .Decentralized-AI-Tutor-System enroll-in-module u1)
```

#### 3.1 Enroll in Module (with Prerequisite Check)
```clarity
(contract-call? .Decentralized-AI-Tutor-System enroll-in-module u2)  ; Fails if prerequisite u1 not completed
```

#### 4. Update Learning Progress
```clarity
(contract-call? .Decentralized-AI-Tutor-System update-progress u1 u75 u85)
```

#### 5. Create Content Bounty
#### 6. Register with Referral
```clarity
(contract-call? .Decentralized-AI-Tutor-System register-user "student" (some referrer-principal))
```

#### 7. Check Referral Count
```clarity
(contract-call? .Decentralized-AI-Tutor-System get-referral-count user-principal)
```
```clarity
(contract-call? .Decentralized-AI-Tutor-System create-content-bounty
- **👥 Referral Counts**: Track successful user referrals for reputation rewards
  "Spanish Math Course"
  "Create basic mathematics course in Spanish"
  "Spanish"
  "Mathematics"
  u1000000
  u144) ; 1 day deadline
```

## 🏗️ Architecture

### Data Structures
- **👤 Users**: Store user types, reputation, and join dates
- **📚 Learning Modules**: Educational content with metadata and optional prerequisites
- **📈 Progress Tracking**: User completion data per module
- **🏅 Credentials**: Verified completion certificates
- **🎖️ NFT Badges**: Achievement tokens with metadata
- **🗳️ DAO Proposals**: Governance proposals with voting data
- **💰 Bounties**: Content creation incentives

### Security Features
- 🔒 Role-based access control
- ✅ Input validation and error handling
- 🛡️ Unauthorized access prevention
- 📊 Progress verification

## 🎯 Future Enhancements

- 🤖 **AI Integration**: Connect with AI models for adaptive content delivery
- 📱 **Mobile App**: React Native application for mobile learning
- 🌐 **Multi-chain Support**: Expand to other blockchain networks
- 📊 **Analytics Dashboard**: Learning analytics and insights
- 🎮 **Gamification**: Enhanced reward systems and competitions

## 🤝 Contributing

We welcome contributions from the community! Please feel free to submit issues, fork the repository, and create pull requests.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `clarinet test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with ❤️ using Stacks blockchain and Clarity
- Inspired by the vision of democratizing education globally
- Special thanks to the open-source blockchain education community

---

*🌟 Star this repository if you believe in decentralized education!*
