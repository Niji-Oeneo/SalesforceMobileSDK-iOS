/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <SmartStore/SFQuerySpec.h>
#import "SyncManagerTestCase.h"
#import "SFParentChildrenSyncDownTarget.h"
#import "SFSmartSyncObjectUtils.h"

@interface SFParentChildrenSyncDownTarget ()

- (NSString *)getSoqlForRemoteIds;
- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;
- (NSString*) getNonDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;
- (NSOrderedSet *)getNonDirtyRecordIds:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName idField:(NSString *)idField;

@end

@interface ParentChildrenSyncTests : SyncManagerTestCase

@end

@implementation ParentChildrenSyncTests

#pragma mark - setUp/tearDown

- (void)setUp {
    [super setUp];

    [self createTestData];
}

- (void)tearDown {
    // Deleting test data
    [self deleteTestData];

    [super tearDown];
}

#pragma mark - Tests

/**
 * Test getQuery for SFParentChildrenSyncDownTarget
 */
- (void) testGetQuery {
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children) from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getQueryToRun], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = @"select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children) from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getQueryToRun], expectedQuery);
}

/**
 * Test query for reSync by calling getQuery with maxTimeStamp for SFParentChildrenSyncDownTarget
 */
- (void) testGetQueryWithMaxTimeStamp {
    NSDate* date = [NSDate new];
    long long maxTimeStamp = [date timeIntervalSince1970];
    NSString* dateStr = [SFSmartSyncObjectUtils getIsoStringFromMillis:maxTimeStamp];
    
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString* expectedQuery = [NSString stringWithFormat:@"select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children where ChildLastModifiedDate > %@) from Parent where ParentModifiedDate > %@ and School = 'MIT'", dateStr, dateStr];
    XCTAssertEqualObjects([target getQueryToRun:maxTimeStamp], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = [NSString stringWithFormat:@"select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children where LastModifiedDate > %@) from Parent where LastModifiedDate > %@ and School = 'MIT'", dateStr, dateStr];
    XCTAssertEqualObjects([target getQueryToRun:maxTimeStamp], expectedQuery);
}

/**
 * Test getSoqlForRemoteIds for SFParentChildrenSyncDownTarget
 */
- (void) testGetSoqlForRemoteIds {
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"select ParentId from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getSoqlForRemoteIds], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = @"select Id from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getSoqlForRemoteIds], expectedQuery);
}

/**
 * Test testGetDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
 */
- (void) testGetDirtyRecordIdsSql {
    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 1 OR EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)";
    XCTAssertEqualObjects([target getDirtyRecordIdsSql:@"parentsSoup" idField:@"IdForQuery"], expectedQuery);
}

/**
 * Test testGetNonDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
 */
- (void) testGetNonDirtyRecordIdsSql {
    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 0 AND NOT EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)";
    XCTAssertEqualObjects([target getNonDirtyRecordIdsSql:@"parentsSoup" idField:@"IdForQuery"], expectedQuery);
}

/**
 * Test getDirtyRecordIds and getNonDirtyRecordIds for SFParentChildrenSyncDownTarget when parent and/or all and/or some children are dirty
 */
- (void) testGetDirtyAndNonDirtyRecordIds {

    NSArray<NSString *> *accountNames = @[
            [self createAccountName],
            [self createAccountName],
            [self createAccountName],
            [self createAccountName],
            [self createAccountName],
            [self createAccountName]
    ];

    NSDictionary<NSDictionary *, NSArray<NSDictionary *> *> *mapAccountToContacts = [self createAccountsAndContactsLocally:accountNames numberOfContactsPerAccount:3];
    NSArray<NSDictionary *>* accounts = [mapAccountToContacts allKeys];

    // All Accounts should be returned
    [self tryGetDirtyRecordIds:accounts];

    // No accounts should be returned
    [self tryGetNonDirtyRecordIds:@[]];


    // Cleaning up:
    // accounts[0]: dirty account and dirty contacts
    // accounts[1]: clean account and dirty contacts
    // accounts[2]: dirty account and clean contacts
    // accounts[3]: clean account and clean contacts
    // accounts[4]: dirty account and some dirty contacts
    // accounts[5]: clean account and some dirty contacts

    [self  cleanRecord:ACCOUNTS_SOUP record:accounts[1]];
    [self  cleanRecords:CONTACTS_SOUP records:mapAccountToContacts[accounts[2]]];
    [self  cleanRecord:ACCOUNTS_SOUP record:accounts[3]];
    [self  cleanRecords:CONTACTS_SOUP records:mapAccountToContacts[accounts[3]]];
    [self  cleanRecord:CONTACTS_SOUP record:mapAccountToContacts[accounts[4]][0]];
    [self  cleanRecord:ACCOUNTS_SOUP record:accounts[5]];
    [self  cleanRecord:CONTACTS_SOUP record:mapAccountToContacts[accounts[5]][0]];

    // Only clean account with clean contacts should not be returned
    [self tryGetDirtyRecordIds:@[accounts[0], accounts[1], accounts[2], accounts[4], accounts[5]]];

    // Only clean account with clean contacts should be returned
    [self tryGetNonDirtyRecordIds:@[accounts[3]]];
}


/**
  * Test saveRecordsToLocalStore
  */
- (void) testSaveRecordsToLocalStore {

    // Putting together an array of accounts with contacts
    // looking like what we would get back from startFetch/continueFetch
    // - not having local fields
    // - not have _soupEntryId field
    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;

    NSDictionary * accountAttributes = @{TYPE: ACCOUNT_TYPE};
    NSDictionary * contactAttributes = @{TYPE: CONTACT_TYPE};

    NSMutableArray* accounts = [NSMutableArray new];
    NSMutableDictionary * mapAccountContacts = [NSMutableDictionary new];

    for (NSUInteger i = 0; i<numberAccounts; i++) {
        NSDictionary * account = @{ID: [self createLocalId], ATTRIBUTES: accountAttributes};
        NSMutableArray * contacts = [NSMutableArray new];
        for (NSUInteger j = 0; j < numberContactsPerAccount; j++) {
            [contacts addObject:@{ID: [self createLocalId], ATTRIBUTES: contactAttributes, ACCOUNT_ID: account[ID]}];
        }
        mapAccountContacts[account] = contacts;
        [accounts addObject:account];
    }

    NSMutableArray * records = [NSMutableArray new];
    for (NSDictionary * account in accounts) {
        NSMutableDictionary * record = [account mutableCopy];
        NSMutableArray * contacts = [NSMutableArray new];
        for (NSDictionary * contact in mapAccountContacts[account]) {
            [contacts addObject:contact];
        }
        record[@"Contacts"] = contacts;
        [records addObject:record];
    }

    // Now calling saveRecordsToLocalStore
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTarget];
    [target saveRecordsToLocalStore:self.syncManager soupName:ACCOUNTS_SOUP records:records];

    // Checking accounts and contacts soup
    // Making sure local fields are populated
    // Making sure accountId and accountLocalId fields are populated on contacts

    NSMutableArray * accountIds = [NSMutableArray new];
    for (NSDictionary * account in accounts) {
        [accountIds addObject:account[ID]];
    }
    NSArray<NSDictionary *> *accountsFromDb = [self queryWithInClause:ACCOUNTS_SOUP fieldName:ID values:accountIds orderBy:SOUP_ENTRY_ID];
    XCTAssertEqual(accountsFromDb.count, accounts.count, @"Wrong number of accounts in db");

    for (NSUInteger i = 0; i < accountsFromDb.count; i++) {
        NSDictionary * account = accounts[i];
        NSDictionary * accountFromDb = accountsFromDb[i];

        XCTAssertEqualObjects(accountFromDb[ID], account[ID]);
        XCTAssertEqualObjects(accountFromDb[ATTRIBUTES][TYPE], ACCOUNT_TYPE);
        XCTAssertEqualObjects(@NO, accountFromDb[kSyncTargetLocal]);
        XCTAssertEqualObjects(@NO, accountFromDb[kSyncTargetLocallyCreated]);
        XCTAssertEqualObjects(@NO, accountFromDb[kSyncTargetLocallyUpdated]);
        XCTAssertEqualObjects(@NO, accountFromDb[kSyncTargetLocallyDeleted]);

        NSArray<NSDictionary *>* contactsFromDb = [self queryWithInClause:CONTACTS_SOUP fieldName:ACCOUNT_ID values:@[account[ID]] orderBy:SOUP_ENTRY_ID];
        NSArray<NSDictionary *>* contacts = mapAccountContacts[account];
        XCTAssertEqual(contactsFromDb.count, contacts.count, @"Wrong number of accounts in db");

        for (NSUInteger j = 0; j < contactsFromDb.count; j++) {
            NSDictionary *  contact = contacts[j];
            NSDictionary *  contactFromDb = contactsFromDb[j];

            XCTAssertEqualObjects(contactFromDb[ID], contact[ID]);
            XCTAssertEqualObjects(contactFromDb[ATTRIBUTES][TYPE], CONTACT_TYPE);
            XCTAssertEqualObjects(@NO, contactFromDb[kSyncTargetLocal]);
            XCTAssertEqualObjects(@NO, contactFromDb[kSyncTargetLocallyCreated]);
            XCTAssertEqualObjects(@NO, contactFromDb[kSyncTargetLocallyUpdated]);
            XCTAssertEqualObjects(@NO, contactFromDb[kSyncTargetLocallyDeleted]);
            XCTAssertEqualObjects(accountFromDb[ID], contactFromDb[ACCOUNT_ID]);
        }
    }
}

/**
 * Test getLatestModificationTimeStamp
 */
- (void) testGetLatestModificationTimeStamp
{
    // Putting together a JSONArray of accounts with contacts
    // looking like what we would get back from startFetch/continueFetch
    // with different fields for last modified time
    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;


    NSMutableArray<NSNumber*> *timeStamps = [NSMutableArray new];
    NSMutableArray<NSString*> *timeStampStrs = [NSMutableArray new];
    for (NSUInteger i = 1; i<5; i++) {
        long long int millis = i*100000000;
        [timeStamps addObject:[NSNumber numberWithLongLong:millis]];
        [timeStampStrs addObject:[SFSmartSyncObjectUtils getIsoStringFromMillis:millis]];
    }

    NSDictionary * accountAttributes = @{TYPE: ACCOUNT_TYPE};
    NSDictionary * contactAttributes = @{TYPE: CONTACT_TYPE};

    NSMutableArray* accounts = [NSMutableArray new];
    NSMutableDictionary * mapAccountContacts = [NSMutableDictionary new];

    for (NSUInteger i = 0; i<numberAccounts; i++) {
        NSDictionary * account = @{ID: [self createLocalId],
                ATTRIBUTES: accountAttributes,
                @"AccountTimeStamp1": timeStampStrs[i % timeStampStrs.count],
                @"AccountTimeStamp2": timeStampStrs[0]
        };
        NSMutableArray * contacts = [NSMutableArray new];
        for (NSUInteger j = 0; j < numberContactsPerAccount; j++) {
            [contacts addObject:@{ID: [self createLocalId],
                    ATTRIBUTES: contactAttributes,
                    ACCOUNT_ID: account[ID],
                    @"ContactTimeStamp1": timeStampStrs[1],
                    @"ContactTimeStamp2": timeStampStrs[j % timeStampStrs.count]
            }
            ];
        }
        mapAccountContacts[account] = contacts;
        [accounts addObject:account];
    }

    NSMutableArray * records = [NSMutableArray new];
    for (NSDictionary * account in accounts) {
        NSMutableDictionary * record = [account mutableCopy];
        NSMutableArray * contacts = [NSMutableArray new];
        for (NSDictionary * contact in mapAccountContacts[account]) {
            [contacts addObject:contact];
        }
        record[@"Contacts"] = contacts;
        [records addObject:record];
    }

    // Maximums

    // Get max time stamps based on fields AccountTimeStamp1 / ContactTimeStamp1
    SFParentChildrenSyncDownTarget *target = [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:@"AccountTimeStamp1" contactModificationDateFieldName:@"ContactTimeStamp1" parentSoqlFilter:nil];
    XCTAssertEqual(
            [target getLatestModificationTimeStamp:records],
            [timeStamps[3] longLongValue]
    );

    // Get max time stamps based on fields AccountTimeStamp1 / ContactTimeStamp2
    target = [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:@"AccountTimeStamp1" contactModificationDateFieldName:@"ContactTimeStamp2" parentSoqlFilter:nil];
    XCTAssertEqual(
            [target getLatestModificationTimeStamp:records],
            [timeStamps[3] longLongValue]
    );

    // Get max time stamps based on fields AccountTimeStamp2 / ContactTimeStamp1
    target = [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:@"AccountTimeStamp2" contactModificationDateFieldName:@"ContactTimeStamp1" parentSoqlFilter:nil];
    XCTAssertEqual(
            [target getLatestModificationTimeStamp:records],
            [timeStamps[1] longLongValue]
    );

    // Get max time stamps based on fields AccountTimeStamp2 / ContactTimeStamp2
    target = [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:@"AccountTimeStamp2" contactModificationDateFieldName:@"ContactTimeStamp2" parentSoqlFilter:nil];
    XCTAssertEqual(
            [target getLatestModificationTimeStamp:records],
            [timeStamps[2] longLongValue]
    );
}

#pragma mark - Helper methods

- (void)createTestData {
    [self createAccountsSoup];
    [self createContactsSoup];
}

- (void)deleteTestData {
    [self dropAccountsSoup];
    [self dropContactsSoup];
}

- (NSDictionary<NSDictionary*, NSArray<NSDictionary*>*>*) createAccountsAndContactsLocally:(NSArray<NSString*>*)names
                                                                numberOfContactsPerAccount:(NSUInteger)numberOfContactsPerAccount
{
    NSArray<NSDictionary *>* accounts = [self createAccountsLocally:names];
    NSMutableArray * accountIds = [NSMutableArray new];
    for (NSDictionary * account in accounts) {
        [accountIds addObject:account[ID]];
    }

    NSDictionary<NSDictionary *, NSArray<NSDictionary *> *> *accountIdsToContacts = [self createContactsForAccountsLocally:numberOfContactsPerAccount accountIds:accountIds];

    NSMutableDictionary<NSDictionary*, NSArray<NSDictionary*>*>* accountToContacts = [NSMutableDictionary new];

    for (NSDictionary * account in accounts) {
        accountToContacts[account] = accountIdsToContacts[account[ID]];
    }
    return accountToContacts;
}

- (NSDictionary<NSDictionary*, NSArray<NSDictionary*>*>*) createContactsForAccountsLocally:(NSUInteger)numberOfContactsPerAccount
                                                                                accountIds:(NSArray<NSString*>*)accountIds
{
    NSMutableDictionary<NSDictionary *, NSArray<NSDictionary *> *> *accountIdsToContacts = [NSMutableDictionary new];

    NSDictionary *attributes = @{TYPE: ACCOUNT_TYPE};
    for (NSString *accountId in accountIds) {
        NSMutableArray<NSDictionary *>* contacts = [NSMutableArray new];
        for (NSUInteger i=0; i<numberOfContactsPerAccount; i++) {
            NSDictionary *contact = @{
                    ID: [self createLocalId],
                    LAST_NAME: [self createRecordName:CONTACT_TYPE],
                    ATTRIBUTES: attributes,
                    ACCOUNT_ID: accountId,
                    kSyncTargetLocal: @YES,
                    kSyncTargetLocallyCreated: @YES,
                    kSyncTargetLocallyUpdated: @NO,
                    kSyncTargetLocallyDeleted: @NO,
            };
            [contacts addObject:contact];
        }
        accountIdsToContacts[accountId] = [self.store upsertEntries:contacts toSoup:CONTACTS_SOUP];
    }
    return accountIdsToContacts;
}

- (void) tryGetDirtyRecordIds:(NSArray*) expectedRecords
{
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTarget];
    NSOrderedSet* dirtyRecordIds = [target getDirtyRecordIds:self.syncManager soupName:ACCOUNTS_SOUP idField:ID];
    XCTAssertEqual(dirtyRecordIds.count, expectedRecords.count);

    for (NSDictionary * expectedRecord in expectedRecords) {
        XCTAssertTrue([dirtyRecordIds containsObject:expectedRecord[ID]]);
    }
}

- (void) tryGetNonDirtyRecordIds:(NSArray*) expectedRecords
{
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTarget];
    NSOrderedSet* nonDirtyRecordIds = [target getNonDirtyRecordIds:self.syncManager soupName:ACCOUNTS_SOUP idField:ID];
    XCTAssertEqual(nonDirtyRecordIds.count, expectedRecords.count);

    for (NSDictionary * expectedRecord in expectedRecords) {
        XCTAssertTrue([nonDirtyRecordIds containsObject:expectedRecord[ID]]);
    }
}

- (void) cleanRecords:(NSString*)soupName records:(NSArray*)records {
    NSMutableArray * cleanRecords = [NSMutableArray new];
    for (NSDictionary * record in records) {
        NSMutableDictionary * mutableRecord = [record mutableCopy];
        mutableRecord[kSyncTargetLocal] = @NO;
        mutableRecord[kSyncTargetLocallyCreated] = @NO;
        mutableRecord[kSyncTargetLocallyUpdated] = @NO;
        mutableRecord[kSyncTargetLocallyDeleted] = @NO;
        [cleanRecords addObject:mutableRecord];
    }
    [self.store upsertEntries:cleanRecords toSoup:soupName];
}

- (void) cleanRecord:(NSString*)soupName record:(NSDictionary*)record {
    [self cleanRecords:soupName records:@[record]];
}


- (SFParentChildrenSyncDownTarget*) getAccountContactsSyncDownTarget {
    return [self getAccountContactsSyncDownTargetWithParentSoqlFilter:@""];
}

- (SFParentChildrenSyncDownTarget*)getAccountContactsSyncDownTargetWithParentSoqlFilter:(NSString*) parentSoqlFilter {
    return [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:LAST_MODIFIED_DATE contactModificationDateFieldName:LAST_MODIFIED_DATE parentSoqlFilter:parentSoqlFilter];
}

- (SFParentChildrenSyncDownTarget*)getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:(NSString *)accountModificationDateFieldName
                                                                       contactModificationDateFieldName:(NSString *)contactModificationDateFieldName
                                                                                       parentSoqlFilter:(NSString*) parentSoqlFilter {

    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:ACCOUNT_TYPE soupName:ACCOUNTS_SOUP idFieldName:ID modificationDateFieldName:accountModificationDateFieldName]
                        parentFieldlist:@[ID, NAME, DESCRIPTION]
                       parentSoqlFilter:parentSoqlFilter
                           childrenInfo:[SFChildrenInfo newWithSObjectType:CONTACT_TYPE sobjectTypePlural:@"Contacts" soupName:CONTACTS_SOUP parentIdFieldName:ACCOUNT_ID idFieldName:ID modificationDateFieldName:contactModificationDateFieldName]
                      childrenFieldlist:@[LAST_NAME, ACCOUNT_ID]
                       relationshipType:SFParentChildrenRelationpshipMasterDetail]; // account-contacts are master-detail
    return target;
}

- (NSArray<NSDictionary*>*) queryWithInClause:(NSString*)soupName fieldName:(NSString*)fieldName values:(NSArray<NSString*>*)values orderBy:(NSString*)orderBy
{
    NSString* sql = [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@} WHERE {%@:%@} IN %@ %@",
            soupName, @"_soup", soupName, soupName, fieldName,
            [self buildInClause:values],
            orderBy == nil ? @"" : [NSString stringWithFormat:@" ORDER BY {%@:%@} ASC", soupName, orderBy]
            ];

    SFQuerySpec * querySpec = [SFQuerySpec newSmartQuerySpec:sql withPageSize:INT_MAX];
    NSArray* rows = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    NSMutableArray * arr = [NSMutableArray new];
    for (NSUInteger i = 0; i < rows.count; i++) {
        arr[i] = rows[i][0];
    }
    return arr;
}


@end
