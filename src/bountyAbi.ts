export const BOUNTY_ABI = [
  { type: 'function', name: 'getBounties', inputs: [], outputs: [{ name: '', type: 'tuple[]', components: [
    { name: 'id', type: 'uint256' }, { name: 'creator', type: 'address' }, { name: 'title', type: 'string' },
    { name: 'description', type: 'string' }, { name: 'reward', type: 'uint256' }, { name: 'status', type: 'uint8' },
    { name: 'claimer', type: 'address' }, { name: 'tags', type: 'string' }, { name: 'deadline', type: 'uint256' },
    { name: 'acceptanceCriteria', type: 'string' }, { name: 'bountyType', type: 'uint8' }, { name: 'estimatedHours', type: 'uint256' },
  ]}], stateMutability: 'view' },
  { type: 'function', name: 'getSubmissions', inputs: [{ name: 'bountyId', type: 'uint256' }], outputs: [{ name: '', type: 'tuple[]', components: [
    { name: 'submitter', type: 'address' }, { name: 'submissionNote', type: 'string' }, { name: 'timestamp', type: 'uint256' },
  ]}], stateMutability: 'view' },
  { type: 'function', name: 'getReputation', inputs: [{ name: 'user', type: 'address' }], outputs: [
    { name: 'earned', type: 'uint256' }, { name: 'won', type: 'uint256' }, { name: 'created', type: 'uint256' },
  ], stateMutability: 'view' },
  { type: 'function', name: 'createBounty', inputs: [
    { name: 'title', type: 'string' }, { name: 'description', type: 'string' }, { name: 'reward', type: 'uint256' },
    { name: 'tags', type: 'string' }, { name: 'deadline', type: 'uint256' }, { name: 'acceptanceCriteria', type: 'string' },
    { name: 'bountyType', type: 'uint8' }, { name: 'estimatedHours', type: 'uint256' },
  ], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'submitWork', inputs: [{ name: 'bountyId', type: 'uint256' }, { name: 'submissionNote', type: 'string' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'approveClaimer', inputs: [{ name: 'bountyId', type: 'uint256' }, { name: 'claimer', type: 'address' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'cancelBounty', inputs: [{ name: 'bountyId', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'claimExpiredBounty', inputs: [{ name: 'bountyId', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'withdrawSubmission', inputs: [{ name: 'bountyId', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'tipWinner', inputs: [{ name: 'bountyId', type: 'uint256' }, { name: 'amount', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
] as const
