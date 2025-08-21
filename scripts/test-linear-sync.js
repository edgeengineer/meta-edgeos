#!/usr/bin/env node

// Test script for Linear API integration
// Usage: LINEAR_API_KEY=your-key LINEAR_TEAM_ID=your-team-id node test-linear-sync.js

const https = require('https');

const LINEAR_API_KEY = process.env.LINEAR_API_KEY;
const LINEAR_TEAM_ID = process.env.LINEAR_TEAM_ID;
let ACTUAL_TEAM_UUID = null; // Will be set after Test 1

if (!LINEAR_API_KEY || !LINEAR_TEAM_ID) {
  console.error('Please set LINEAR_API_KEY and LINEAR_TEAM_ID environment variables');
  process.exit(1);
}

// Function to make Linear API requests
async function linearRequest(query, variables = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ query, variables });
    
    const options = {
      hostname: 'api.linear.app',
      port: 443,
      path: '/graphql',
      method: 'POST',
      headers: {
        'Authorization': LINEAR_API_KEY,
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };
    
    const req = https.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const parsed = JSON.parse(responseData);
          if (parsed.errors) {
            console.error('GraphQL Errors:', JSON.stringify(parsed.errors, null, 2));
            reject(new Error(parsed.errors[0].message));
          } else {
            resolve(parsed);
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// Test 1: Get team info
async function testGetTeam() {
  console.log('\n=== Test 1: Get Team Info ===');
  const query = `
    query GetTeam($id: String!) {
      team(id: $id) {
        id
        name
        key
      }
    }
  `;
  
  try {
    const result = await linearRequest(query, { id: LINEAR_TEAM_ID });
    console.log('✅ Team found:', result.data.team);
    ACTUAL_TEAM_UUID = result.data.team.id; // Store the UUID for later use
    return true;
  } catch (error) {
    console.error('❌ Failed to get team:', error.message);
    return false;
  }
}

// Test 2: Get workflow states
async function testGetStates() {
  console.log('\n=== Test 2: Get Workflow States ===');
  const query = `
    query GetStates($teamId: ID!) {
      workflowStates(filter: { team: { id: { eq: $teamId } } }) {
        nodes {
          id
          name
          type
        }
      }
    }
  `;
  
  try {
    const result = await linearRequest(query, { teamId: ACTUAL_TEAM_UUID || LINEAR_TEAM_ID });
    console.log('✅ Found', result.data.workflowStates.nodes.length, 'workflow states:');
    result.data.workflowStates.nodes.forEach(state => {
      console.log(`  - ${state.name} (${state.type}): ${state.id}`);
    });
    return result.data.workflowStates.nodes;
  } catch (error) {
    console.error('❌ Failed to get states:', error.message);
    
    // Try alternative without filter
    console.log('\n  Trying alternative query...');
    const altQuery = `
      query {
        workflowStates {
          nodes {
            id
            name
            type
            team {
              id
              key
            }
          }
        }
      }
    `;
    
    try {
      const altResult = await linearRequest(altQuery);
      const teamStates = altResult.data.workflowStates.nodes.filter(
        s => s.team.id === (ACTUAL_TEAM_UUID || LINEAR_TEAM_ID) || s.team.key === LINEAR_TEAM_ID
      );
      console.log('  ✅ Found', teamStates.length, 'workflow states for team:');
      teamStates.forEach(state => {
        console.log(`  - ${state.name} (${state.type}): ${state.id}`);
      });
      return teamStates;
    } catch (altError) {
      console.error('  ❌ Alternative query also failed:', altError.message);
      return [];
    }
  }
}

// Test 3: Search for issues
async function testSearchIssues() {
  console.log('\n=== Test 3: Search for Issues ===');
  const testUrl = 'https://github.com/test/test/issues/1';
  
  // Fixed query - use searchableContent instead of description filter
  const query = `
    query SearchIssues($searchText: String!) {
      searchIssues(term: $searchText) {
        nodes {
          id
          identifier
          title
          description
        }
      }
    }
  `;
  
  try {
    const result = await linearRequest(query, { searchText: testUrl });
    console.log('✅ Search completed. Found', result.data.searchIssues.nodes.length, 'issues');
    return true;
  } catch (error) {
    console.error('❌ Failed to search issues:', error.message);
    
    // Try alternative query
    console.log('\n  Trying alternative query...');
    const altQuery = `
      query GetIssues($teamId: String!) {
        issues(first: 10, filter: { team: { id: { eq: $teamId } } }) {
          nodes {
            id
            identifier
            title
          }
        }
      }
    `;
    
    try {
      const altResult = await linearRequest(altQuery, { teamId: LINEAR_TEAM_ID });
      console.log('  ✅ Alternative query worked. Found', altResult.data.issues.nodes.length, 'recent issues');
      return true;
    } catch (altError) {
      console.error('  ❌ Alternative query also failed:', altError.message);
      return false;
    }
  }
}

// Test 4: Create a test issue
async function testCreateIssue(states) {
  console.log('\n=== Test 4: Create Test Issue ===');
  
  if (!states || states.length === 0) {
    console.log('⚠️  Skipping: No workflow states available');
    return null;
  }
  
  const todoState = states.find(s => s.type === 'unstarted' || s.type === 'backlog') || states[0];
  console.log(`  Using state: ${todoState.name} (${todoState.type})`);
  
  // Use the UUID we got from Test 1
  const actualTeamId = ACTUAL_TEAM_UUID || '658b3d04-9cb2-4ed0-bf59-3252d9d665c4';
  
  const mutation = `
    mutation CreateIssue($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue {
          id
          identifier
          url
          title
        }
      }
    }
  `;
  
  const testIssue = {
    teamId: actualTeamId,
    title: '[TEST] GitHub Integration Test Issue',
    description: 'This is a test issue created to verify GitHub-Linear integration. GitHub Issue: https://github.com/test/test/issues/999. Created by: Test Script. Created at: ' + new Date().toISOString() + '. This issue can be safely deleted.',
    stateId: todoState.id
  };
  
  console.log('  Sending mutation with teamId:', actualTeamId);
  console.log('  StateId:', todoState.id);
  console.log('  Full input:', JSON.stringify(testIssue, null, 2));
  
  try {
    const result = await linearRequest(mutation, { input: testIssue });
    console.log('  Raw result:', JSON.stringify(result, null, 2));
    
    if (result.data && result.data.issueCreate && result.data.issueCreate.success) {
      console.log('✅ Test issue created successfully:');
      console.log('  ID:', result.data.issueCreate.issue.identifier);
      console.log('  URL:', result.data.issueCreate.issue.url);
      return result.data.issueCreate.issue;
    } else {
      console.error('❌ Failed to create issue');
      if (result.data) {
        console.error('  Response data:', JSON.stringify(result.data, null, 2));
      }
      if (result.errors) {
        console.error('  Errors:', JSON.stringify(result.errors, null, 2));
      }
      return null;
    }
  } catch (error) {
    console.error('❌ Failed to create issue:', error.message);
    console.error('  Stack:', error.stack);
    return null;
  }
}

// Test 5: Update the test issue
async function testUpdateIssue(issue) {
  if (!issue) {
    console.log('\n=== Test 5: Update Issue ===');
    console.log('⚠️  Skipping: No test issue to update');
    return;
  }
  
  console.log('\n=== Test 5: Update Test Issue ===');
  
  const mutation = `
    mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue {
          id
          title
          description
        }
      }
    }
  `;
  
  const update = {
    title: '[TEST] Updated GitHub Integration Test Issue',
    description: issue.description + '\n\n**Updated at**: ' + new Date().toISOString()
  };
  
  try {
    const result = await linearRequest(mutation, { id: issue.id, input: update });
    if (result.data.issueUpdate.success) {
      console.log('✅ Issue updated successfully');
    } else {
      console.log('❌ Failed to update issue');
    }
  } catch (error) {
    console.error('❌ Failed to update issue:', error.message);
  }
}

// Test 6: Add comment to test issue
async function testAddComment(issue) {
  if (!issue) {
    console.log('\n=== Test 6: Add Comment ===');
    console.log('⚠️  Skipping: No test issue to comment on');
    return;
  }
  
  console.log('\n=== Test 6: Add Comment to Test Issue ===');
  
  const mutation = `
    mutation AddComment($issueId: String!, $body: String!) {
      commentCreate(input: { issueId: $issueId, body: $body }) {
        success
        comment {
          id
          body
        }
      }
    }
  `;
  
  const comment = `**Test Comment from GitHub Integration**
  
This is a test comment to verify that GitHub comments can be synced to Linear.

Posted at: ${new Date().toISOString()}`;
  
  try {
    const result = await linearRequest(mutation, { issueId: issue.id, body: comment });
    if (result.data.commentCreate.success) {
      console.log('✅ Comment added successfully');
    } else {
      console.log('❌ Failed to add comment');
    }
  } catch (error) {
    console.error('❌ Failed to add comment:', error.message);
  }
}

// Test 7: Delete test issue
async function testDeleteIssue(issue) {
  if (!issue) {
    console.log('\n=== Test 7: Delete Issue ===');
    console.log('⚠️  Skipping: No test issue to delete');
    return;
  }
  
  console.log('\n=== Test 7: Delete Test Issue ===');
  
  const mutation = `
    mutation DeleteIssue($id: String!) {
      issueDelete(id: $id) {
        success
      }
    }
  `;
  
  try {
    const result = await linearRequest(mutation, { id: issue.id });
    if (result.data.issueDelete.success) {
      console.log('✅ Test issue deleted successfully');
    } else {
      console.log('❌ Failed to delete issue');
    }
  } catch (error) {
    console.error('❌ Failed to delete issue:', error.message);
  }
}

// Run all tests
async function runTests() {
  console.log('Starting Linear API Integration Tests');
  console.log('=====================================');
  console.log('API Key:', LINEAR_API_KEY.substring(0, 10) + '...');
  console.log('Team ID:', LINEAR_TEAM_ID);
  
  // Run tests in sequence
  const teamOk = await testGetTeam();
  if (!teamOk) {
    console.error('\n❌ Cannot proceed without valid team. Check your LINEAR_TEAM_ID');
    process.exit(1);
  }
  
  const states = await testGetStates();
  await testSearchIssues();
  const testIssue = await testCreateIssue(states);
  
  if (testIssue) {
    // Wait a bit before updating
    await new Promise(resolve => setTimeout(resolve, 1000));
    await testUpdateIssue(testIssue);
    await testAddComment(testIssue);
    
    // Ask user if they want to delete the test issue
    console.log('\n' + '='.repeat(50));
    console.log('Test issue created:', testIssue.url);
    console.log('The test issue will be automatically deleted in 5 seconds...');
    console.log('Press Ctrl+C to keep it for inspection');
    
    await new Promise(resolve => setTimeout(resolve, 5000));
    await testDeleteIssue(testIssue);
  }
  
  console.log('\n' + '='.repeat(50));
  console.log('✅ All tests completed!');
}

// Run the tests
runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});