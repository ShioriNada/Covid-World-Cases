--Data exploration project: Covid Cases and Deaths
--Used skills: Join, CTE, Window Functions, Temp tables, Create Views

SELECT *
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
ORDER BY 3,4

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM dbo.[CovidDeaths-May22]
ORDER BY 1,2

--Looking at Total Cases vs Total Deaths
--Shows likelifood of dying if you contract covid in your country
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM dbo.[CovidDeaths-May22]
WHERE location = 'Canada' AND 
continent IS NOT NULL
ORDER BY 1,2

--Looking at Total Cases vs Population
--Shows what percentage of population got Covid
SELECT location, date, population, total_cases, (total_cases/population)*100 AS PercentPopulationInfected
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
ORDER BY 1,2

--Looking at countries with highest infection rate compared to population by day
--Shows
SELECT location, population, date, MAX(total_cases) AS HighestInfectionCount, 
MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
GROUP BY location, population, date
ORDER BY PercentPopulationInfected DESC

--Highest infection rate and compared to population by country
SELECT location, population, MAX(total_cases) AS HighestInfectionCount, 
MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC

-- Showing countries with highest death count per population
SELECT location, MAX(cast(total_deaths as int)) AS TotalDeathCount
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC

--LET'S BREAK THINGS DOWN BY CONTINENT
--Showing continents with the highest death count

SELECT location, MAX(cast(total_deaths as int)) AS TotalDeathCount
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NULL
AND location NOT IN 
('World','Upper middle income', 'High income', 'Lower middle income', 'European Union', 'Low income', 'international')
GROUP BY location
ORDER BY TotalDeathCount DESC

SELECT continent, MAX(cast(total_deaths as int)) AS TotalDeathCount
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC

--Death per capita ranking by country
WITH temp AS (
SELECT location, continent, population, MAX(cast(total_deaths as int)) AS TotalDeathCount,
	   SUM(CAST(new_deaths AS int))/MAX(population)*100 AS DeathPerCapita
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
GROUP BY location, continent, population
)

SELECT location, continent, population, TotalDeathCount, DeathPerCapita, RANK() OVER (ORDER BY DeathPerCapita DESC) AS Rank
FROM temp
ORDER BY DeathPerCapita DESC


--GLOBAL NUMBERS

SELECT date, SUM(new_cases) AS total_new_cases, SUM(CAST(new_deaths AS int)) AS total_new_deaths, SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS DeathPercentage
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1

SELECT SUM(new_cases) AS total_new_cases, SUM(CAST(new_deaths AS int)) AS total_new_deaths, SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS DeathPercentage
FROM dbo.[CovidDeaths-May22]
WHERE continent IS NOT NULL
--GROUP BY date
ORDER BY 1


--Looking at Total Vaccination vs Population
With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccined)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CONVERT(bigint, vac.new_vaccinations)) OVER(PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM dbo.[CovidVaccinations-May22] AS vac
 INNER JOIN dbo.[CovidDeaths-May22] AS dea
 ON vac.location = dea.location AND vac.date = dea.date
WHERE dea.continent IS NOT NULL
)
SELECT *, (RollingPeopleVaccined/Population)*100
FROM PopvsVac

-- TEMP TABLE
CREATE TABLE #PercentPopulationVaccinatedMay
(
Continent nvarchar(255), 
Location nvarchar(255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
RollingPeopleVaccinated numeric
)

INSERT INTO #PercentPopulationVaccinatedMay
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CONVERT(bigint, vac.new_vaccinations)) OVER(PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM dbo.[CovidVaccinations-May22]AS vac
 INNER JOIN dbo.[CovidDeaths-May22] AS dea
 ON vac.location = dea.location AND vac.date = dea.date
WHERE dea.continent IS NOT NULL

SELECT *, (RollingPeopleVaccinated/Population)*100
FROM #PercentPopulationVaccinatedMay

--Creating view

DROP VIEW IF EXISTS PercentPopulationVaccinatedMay

GO

Create View PercentPopulationVaccinatedMay
AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CONVERT(bigint, vac.new_vaccinations)) OVER(PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM dbo.[CovidVaccinations-May22] AS vac
 INNER JOIN dbo.[CovidDeaths-May22] AS dea
 ON vac.location = dea.location AND vac.date = dea.date
WHERE dea.continent IS NOT NULL

SELECT *
FROM PercentPopulationVaccinatedMay;

--Join 3 tables 
SELECT sub.location, 
       sub.continent, 
	   MAX(sub.population) AS population, 
	   MAX(RollingPeopleVaccinated) AS people_vaccinated, 
	   AVG(oth.aged_65_older) AS aged65_older,
	   AVG(oth.gdp_per_capita) AS gdp_per_capita,
	   AVG(oth.diabetes_prevalence) AS diabetes,
	   AVG(oth.life_expectancy) AS life_expectancy
FROM (
	SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
	SUM(CONVERT(bigint, vac.new_vaccinations)) OVER(PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
	FROM dbo.[CovidVaccinations-May22] AS vac
	INNER JOIN dbo.[CovidDeaths-May22] AS dea
	ON vac.location = dea.location AND vac.date = dea.date
	WHERE dea.continent IS NOT NULL
	) AS sub
 INNER JOIN dbo.[CovidOtherInfo-May22]  AS oth
 ON sub.location = oth.location AND sub.date = oth.date
GROUP BY sub.location, sub.continent
