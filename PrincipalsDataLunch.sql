IF OBJECT_ID('tempdb..#temp') IS NOT NULL
	DROP TABLE #temp
IF OBJECT_ID('tempdb..#temp2') IS NOT NULL
	DROP TABLE #temp2
IF OBJECT_ID('tempdb..#temp3') IS NOT NULL
	DROP TABLE #temp3
IF OBJECT_ID('tempdb..#temp4') IS NOT NULL
	DROP TABLE #temp4



SELECT DISTINCT
	inst.FLA_STATE_HS_CODE
	,inst.INST_NM
	,cred.ACT_GRAD_DT
	,cred.STDNT_ID
	,cred.DIPL_TYPE
	,stdnt.SEX
	,CASE 
		WHEN ISNULL(MAX(deved.[DE1050-HSCHOOL-DEV]), 'Never Attended') = '' THEN 'Pre SB1720'
		ELSE ISNULL(MAX(deved.[DE1050-HSCHOOL-DEV]), 'Never Attended') 
	END AS [DE1050-HSCHOOL-DEV]
	,ISNULL(SUM(CAST(r8.[3209_AidAmount] AS INT)), 0) AS [Aid Awarded]
INTO
	#temp
FROM
	MIS.dbo.ST_EXTRNL_CRDNTL_A_141 cred
	INNER JOIN MIS.dbo.ST_INSTITUTION_A_166 inst ON inst.INST_ID = cred.INST_ID
	INNER JOIN MIS.dbo.ST_STDNT_A_125 stdnt ON stdnt.STUDENT_SSN = cred.STDNT_ID
	LEFT JOIN MIS.dbo.ST_STDNT_A_PREV_STDNT_SSN_USED_125 prev ON prev.ISN_ST_STDNT_A = stdnt.ISN_ST_STDNT_A
	LEFT JOIN (SELECT
					r1.[STUDENT-ID], xwalk.OrionTerm, r1.[DE1050-HSCHOOL-DEV]
					,ROW_NUMBER() OVER (PARTITION BY r1.[STUDENT-ID] ORDER BY xwalk.OrionTerm DESC) RN
				FROM
					StateSubmission.SDB.RecordType1 r1
					INNER JOIN MIS.dbo.vwTermYearXwalk xwalk ON xwalk.StateReportingTerm = r1.[TERM-ID]) deved ON deved.[STUDENT-ID] IN (stdnt.STUDENT_SSN, prev.PREV_STDNT_SSN)
	LEFT JOIN StateSubmission.SDB.RecordType8 r8 ON r8.[1021_StudentId] IN (stdnt.STUDENT_SSN, prev.PREV_STDNT_SSN)
												 AND CAST(CAST(LEFT(cred.ACT_GRAD_DT, 4) AS INT) + 1 AS VARCHAR) = r8.[3202_FinancialAidAcademicYear]
												 AND r8.[3208_AidType] = '101'
WHERE
	LEFT(inst.FLA_STATE_HS_CODE, 2) IN ('16','45')
	AND SUBSTRING(cred.ACT_GRAD_DT, 5, 2) IN ('05','06')
	AND LEFT(cred.ACT_GRAD_DT, 4) IN ('2014','2013','2015','2016')
	AND inst.PUBLIC_PRIVATE_IND = 'S'
	AND deved.RN = 1
	AND cred.CRDNTL_CD = 'HC'
GROUP BY
	inst.FLA_STATE_HS_CODE
	,inst.INST_NM
	,cred.STDNT_ID
	,stdnt.SEX
	,LEFT(cred.ACT_GRAD_DT, 4)
	,cred.ACT_GRAD_DT
	--,r8.[3209_AidAmount]
	--,deved.[DE1050-HSCHOOL-DEV]
	,cred.DIPL_TYPE
ORDER BY
	ACT_GRAD_DT


SELECT
	t.*
	,CASE
		WHEN stdnt.ETHNICITY = 'H' THEN 'H'
		WHEN [W] + [A] + [B] + [I] + [P] > 1 THEN 'M'
		WHEN [W] = 1 THEN 'W'
		WHEN [A] = 1 THEN 'A'
		WHEN [B] = 1 THEN 'B'
		WHEN [I] = 1 THEN 'I'
		WHEN [P] = 1 THEN 'P'
		ELSE 'X'
	END AS [Ethnicity]
	,CASE
		WHEN MAX(demo.STDNT_ID) IS NULL THEN 'Not Exempt'
		ELSE 'Exempt'
	END AS [Dev Ed Exempted]
INTO
	#temp2
FROM
	#temp t
	LEFT JOIN MIS.dbo.ST_STDNT_TEST_DEMO_A_174 demo ON demo.STDNT_ID = t.STDNT_ID
													AND demo.PLACEMENT_AREA IN ('REA','MAT','ENG')
													AND demo.STATUS_IND IN ('F','Z')
	LEFT JOIN MIS.dbo.ST_STDNT_A_125 stdnt ON stdnt.STUDENT_SSN = t.STDNT_ID
	LEFT JOIN (SELECT ISN_ST_STDNT_A, RACE FROM MIS.dbo.ST_STDNT_A_RACE_125) race PIVOT (COUNT (RACE) FOR RACE IN ([W],[A],[B],[I],[X],[P])) AS racepivot ON racepivot.ISN_ST_STDNT_A = stdnt.ISN_ST_STDNT_A
GROUP BY
	t.STDNT_ID
	,t.FLA_STATE_HS_CODE
	,t.ACT_GRAD_DT
	,t.[DE1050-HSCHOOL-DEV]
	,t.INST_NM
	,t.[Aid Awarded]
	,t.SEX
	,[W],[A],[B],[I],[X],[P]
	,stdnt.ETHNICITY
	,t.DIPL_TYPE

SELECT
	t.*
	,CASE
		WHEN LEFT(t.ACT_GRAD_DT, 4) = '2016' AND isir17.WF_IS_C_PELL_ELIG IS NOT NULL THEN 'Eligible'
		WHEN LEFT(t.ACT_GRAD_DT, 4) = '2015' AND isir16.WF_IS_C_PELL_ELIG IS NOT NULL THEN 'Eligible'
		WHEN LEFT(t.ACT_GRAD_DT, 4) = '2014' AND isir15.WF_IS_C_PELL_ELIG IS NOT NULL THEN 'Eligible'
		WHEN LEFT(t.ACT_GRAD_DT, 4) = '2013' AND isir14.WF_IS_C_PELL_ELIG IS NOT NULL THEN 'Eligible'
		ELSE 'Not Pell Eligible'
	END AS [Pell Eligible]
	,CASE
		WHEN MAX(dual.OrionTerm) IS NULL THEN 'Never'
		ELSE MAX(dual.OrionTerm)
	END AS [Last Dual Enrolled Term]
	,CASE
		WHEN MIN(notdual.OrionTerm) IS NULL THEN 'Never'
		ELSE MIN(notdual.OrionTerm)
	END AS [First FSCJ Term]
	,CASE
		WHEN MIN(notdual.OrionTerm) IS NULL THEN 'Never'
		ELSE MIN(notdual.OrionTerm)
	END AS [Last FSCJ Term]
INTO 
	#temp3
FROM
	#temp2 t
	LEFT JOIN MIS.dbo.WW_STUDENT_822 finaidst ON finaidst.WW_ST_SSN = t.STDNT_ID
	LEFT JOIN MIS.dbo.WF_ISIR_1617_932 isir17 ON isir17.WW_STUDENT_ID = finaidst.WW_STUDENT_ID
											  AND isir17.WF_IS_C_PELL_ELIG = 'Y'
	LEFT JOIN MIS.dbo.WF_ISIR_1516_927 isir16 ON isir16.WW_STUDENT_ID = finaidst.WW_STUDENT_ID
											  AND isir16.WF_IS_C_PELL_ELIG = 'Y'
	LEFT JOIN MIS.dbo.WF_ISIR_1415_922 isir15 ON isir15.WW_STUDENT_ID = finaidst.WW_STUDENT_ID
											  AND isir15.WF_IS_C_PELL_ELIG = 'Y'
	LEFT JOIN MIS.dbo.WF_ISIR_1314_917 isir14 ON isir14.WW_STUDENT_ID = finaidst.WW_STUDENT_ID
											  AND isir14.WF_IS_C_PELL_ELIG = 'Y'
	LEFT JOIN MIS.dbo.WF_ISIR_1213_911 isir13 ON isir13.WW_STUDENT_ID = finaidst.WW_STUDENT_ID
											  AND isir13.WF_IS_C_PELL_ELIG = 'Y'
	LEFT JOIN MIS.dbo.ST_STDNT_A_125 stdnt ON stdnt.STUDENT_SSN = t.STDNT_ID
	LEFT JOIN MIS.dbo.ST_STDNT_A_PREV_STDNT_SSN_USED_125 prev ON prev.ISN_ST_STDNT_A = stdnt.ISN_ST_STDNT_A
	LEFT JOIN (SELECT
					r6.DE1021, xwalk.OrionTerm
				FROM
					StateSubmission.SDB.RecordType6 r6
					INNER JOIN MIS.dbo.vwTermYearXwalk xwalk ON xwalk.StateReportingTerm = r6.DE1028
				WHERE
					r6.DE3004 <> 'NN') dual ON dual.DE1021 IN (stdnt.STUDENT_SSN, prev.PREV_STDNT_SSN)
	LEFT JOIN (SELECT
					r6.DE1021, xwalk.OrionTerm
				FROM
					StateSubmission.SDB.RecordType6 r6
					INNER JOIN MIS.dbo.vwTermYearXwalk xwalk ON xwalk.StateReportingTerm = r6.DE1028
				WHERE
					r6.DE3004 = 'NN') notdual ON notdual.DE1021 IN (stdnt.STUDENT_SSN, prev.PREV_STDNT_SSN)
GROUP BY
	t.STDNT_ID
	,t.FLA_STATE_HS_CODE
	,t.ACT_GRAD_DT
	,t.[DE1050-HSCHOOL-DEV]
	,t.INST_NM
	,t.[Aid Awarded]
	,t.SEX
	,t.Ethnicity
	,t.DIPL_TYPE
	,t.[Dev Ed Exempted]
	,isir17.WF_IS_C_PELL_ELIG
	,isir16.WF_IS_C_PELL_ELIG
	,isir15.WF_IS_C_PELL_ELIG
	,isir14.WF_IS_C_PELL_ELIG

SELECT
	t.STDNT_ID
	,t.FLA_STATE_HS_CODE
	,t.ACT_GRAD_DT
	,t.[DE1050-HSCHOOL-DEV]
	,t.INST_NM
	,t.[Aid Awarded]
	,t.SEX
	,t.Ethnicity
	,t.DIPL_TYPE
	,t.[Dev Ed Exempted]
	,t.[Pell Eligible]
	,t.[Last Dual Enrolled Term]
	,t.[First FSCJ Term]
	,t.[Last FSCJ Term]
	,ISNULL(degrank.AWD_TYPE, 'None Achieved') AS [Highest Award Achieved at FSCJ]
INTO
	#temp4
FROM
	(
	SELECT
		t.STDNT_ID
		,t.FLA_STATE_HS_CODE
		,t.ACT_GRAD_DT
		,t.[DE1050-HSCHOOL-DEV]
		,t.INST_NM
		,t.[Aid Awarded]
		,t.SEX
		,t.Ethnicity
		,t.DIPL_TYPE
		,t.[Dev Ed Exempted]
		,t.[Pell Eligible]
		,t.[Last Dual Enrolled Term]
		,t.[First FSCJ Term]
		,t.[Last FSCJ Term]
		,MAX(t.RANK) AS [MaxRank]
	FROM
		(
		SELECT
			t.*
			,degrank.AWD_TYPE
			,degrank.RANK
		FROM
			#temp3 t
			LEFT JOIN MIS.dbo.ST_STDNT_OBJ_AWD_A_178 obj ON obj.STDNT_ID = t.STDNT_ID
			LEFT JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = obj.PGM_ID
													 AND prog.EFF_TRM_D <> ''
													 AND prog.EFF_TRM_D <= obj.ACT_GRAD_TRM
													 AND (prog.END_TRM = '' OR prog.END_TRM >= obj.ACT_GRAD_TRM)
			LEFT JOIN (SELECT
							gen1.FIELD_VALUE AS AWD_TYPE, gen2.FIELD_VALUE AS RANK
						FROM
							MIS.dbo.UTL_CODE_TABLE_120 code
							LEFT JOIN MIS.dbo.UTL_CODE_TABLE_GENERIC_120 gen1 ON gen1.ISN_UTL_CODE_TABLE = code.ISN_UTL_CODE_TABLE
																			  AND gen1.cnxarraycolumn = 0
							LEFT JOIN MIS.dbo.UTL_CODE_TABLE_GENERIC_120 gen2 ON gen2.ISN_UTL_CODE_TABLE = code.ISN_UTL_CODE_TABLE
																			  AND gen2.cnxarraycolumn = 7
						WHERE
							code.TABLE_NAME = 'AWARD-LVL'
							AND code.STATUS = 'A') degrank ON degrank.AWD_TYPE = prog.AWD_TY) t 
		GROUP BY
			t.STDNT_ID
			,t.FLA_STATE_HS_CODE
			,t.ACT_GRAD_DT
			,t.[DE1050-HSCHOOL-DEV]
			,t.INST_NM
			,t.[Aid Awarded]
			,t.SEX
			,t.Ethnicity
			,t.DIPL_TYPE
			,t.[Dev Ed Exempted]
			,t.[Pell Eligible]
			,t.[Last Dual Enrolled Term]
			,t.[First FSCJ Term]
			,t.[Last FSCJ Term]
		) t
		LEFT JOIN (SELECT
						gen1.FIELD_VALUE AS AWD_TYPE, gen2.FIELD_VALUE AS RANK
					FROM
						MIS.dbo.UTL_CODE_TABLE_120 code
						LEFT JOIN MIS.dbo.UTL_CODE_TABLE_GENERIC_120 gen1 ON gen1.ISN_UTL_CODE_TABLE = code.ISN_UTL_CODE_TABLE
																		  AND gen1.cnxarraycolumn = 0
						LEFT JOIN MIS.dbo.UTL_CODE_TABLE_GENERIC_120 gen2 ON gen2.ISN_UTL_CODE_TABLE = code.ISN_UTL_CODE_TABLE
																		  AND gen2.cnxarraycolumn = 7
					WHERE
						code.TABLE_NAME = 'AWARD-LVL'
						AND code.STATUS = 'A' ) degrank ON degrank.RANK = t.MaxRank


