List<Lead> demoLeads = new List<Lead>{
    new Lead(
        FirstName = 'Maya',
        LastName = 'Chen',
        Company = '[JevForce Demo] Northstar Logistics Group',
        Title = 'Chief Operating Officer',
        Industry = 'Transportation',
        AnnualRevenue = 480000000,
        NumberOfEmployees = 4200,
        LeadSource = 'Web',
        Description =
            'We are selecting a platform for a multi-region rollout across 18 business units. ' +
            'Security and procurement reviews begin this month, and the executive steering ' +
            'committee wants a technical workshop this week before the budget meeting.'
    ),
    new Lead(
        FirstName = 'Daniel',
        LastName = 'Ortiz',
        Company = '[JevForce Demo] Harbor Street Goods',
        Title = 'Founder',
        Industry = 'Retail',
        AnnualRevenue = 1800000,
        NumberOfEmployees = 22,
        LeadSource = 'Web',
        Description =
            'We need a straightforward service for our online store before next month. ' +
            'I manage the budget and would like pricing for the standard plan and a short demo.'
    ),
    new Lead(
        FirstName = 'Priya',
        LastName = 'Raman',
        Company = '[JevForce Demo] Meridian Integration Labs',
        Title = 'Head of Alliances',
        Industry = 'Technology',
        AnnualRevenue = 32000000,
        NumberOfEmployees = 280,
        LeadSource = 'Partner Referral',
        Description =
            'We build commerce integrations for regional providers and want to discuss a ' +
            'technology and referral partnership. Our team has three shared customers ready ' +
            'for a joint integration pilot and can meet with alliance leadership next week.'
    ),
    new Lead(
        FirstName = 'Alex',
        LastName = 'Morgan',
        Company = '[JevForce Demo] Independent Research Project',
        Title = 'Researcher',
        Industry = 'Other',
        NumberOfEmployees = 1,
        LeadSource = 'Other',
        Description =
            'I am comparing products for a research paper. There is no company project, ' +
            'approved budget, purchasing authority, or implementation timeline at this stage.'
    )
};

insert demoLeads;

for (Lead demoLead : demoLeads) {
    System.debug(LoggingLevel.ERROR,
        'JEVFORCE_DEMO_LEAD|' + demoLead.Id + '|' +
        demoLead.FirstName + ' ' + demoLead.LastName + '|' + demoLead.Company
    );
}
