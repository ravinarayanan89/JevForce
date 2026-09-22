List<Case> demoCases = new List<Case>{
    new Case(
        Subject = '[JevForce Demo] Checkout fails before authorization',
        Description =
            'Customers cannot complete checkout. Every card payment returns error PX-104 ' +
            'before authorization, even after trying another browser and payment method. ' +
            'Several buyers have abandoned their purchases and we need technical help.',
        Origin = 'Web',
        Status = 'New',
        Priority = 'Low'
    ),
    new Case(
        Subject = '[JevForce Demo] Approved reimbursement is still missing',
        Description =
            'The purchase was reversed five business days ago, but the reimbursement has ' +
            'not appeared. I already checked with my bank and contacted support twice. ' +
            'Please confirm where the money is and when it will be returned.',
        Origin = 'Web',
        Status = 'New',
        Priority = 'Low'
    ),
    new Case(
        Subject = '[JevForce Demo] Fourth contact and nobody owns the problem',
        Description =
            'This is my fourth attempt to get help. I keep being transferred, every agent ' +
            'asks me to repeat the same details, and nothing changes. I am extremely ' +
            'frustrated and need a person to resolve this immediately.',
        Origin = 'Phone',
        Status = 'New',
        Priority = 'Low'
    ),
    new Case(
        Subject = '[JevForce Demo] Withdrawal and balance placed on risk hold',
        Description =
            'My withdrawal is pending and the available balance is restricted while the ' +
            'account is under security review. I was told to wait without being told what ' +
            'documents are required. The funds are needed for supplier payments tomorrow.',
        Origin = 'Web',
        Status = 'New',
        Priority = 'Low'
    )
};

insert demoCases;

for (Case demoCase : demoCases) {
    System.debug(LoggingLevel.ERROR,
        'JEVFORCE_DEMO_CASE|' + demoCase.Id + '|' + demoCase.Subject
    );
}
